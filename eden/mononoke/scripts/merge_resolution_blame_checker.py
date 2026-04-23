#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-strict

"""
Checks if any merge-resolved pushrebase diffs were blamed for trunk breakages.

Runs every 10 minutes (via cron or Dataswarm). Queries three Scuba tables:
  1. mononoke_land_service — merge resolution events (changeset_id)
  2. mononoke_new_commit — maps changeset_id → diff_id
  3. fbsource_breakage_quick_diagnosis_results — trunk breakage blame (diff_id)

If a merge-resolved diff is found in a breakage blame list, emits an ODS
counter and logs a warning for oncall investigation.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
import time

from libfb.py.employee import uid_to_unixname
from libfb.py.thrift_clients.oncall_thrift_client import OncallThriftClient
from phabricator.new_phabricator_graphql_helpers import (
    get_phabricator_diffs_with_custom_return_fields,
    PhabricatorDiffStatus,
)
from phabricator.phabricator_auth_strategy_factory import PhabricatorAuthStrategyFactory
from phabricator.phabricator_graphql_client import PhabricatorGraphQLClientBase
from rfe.py.lib.sql import query_sql_as_dict, ResultType
from rfe.scubadata.scubadata_py3 import ScubaData


logger: logging.Logger = logging.getLogger(__name__)

# How far back to look for merge-resolved pushrebases (seconds).
# Use 1200s (20 min) to overlap with the 10-min run interval.
MERGE_RESOLUTION_LOOKBACK_SECS: int = 1200

# How far back to look for trunk breakage blame (seconds).
# Trunk CI may take hours to detect breakage, so use a wider window.
BLAME_LOOKBACK_SECS: int = 14400  # 4 hours

# How far back to look for merge-resolved diffs for revert detection (seconds).
# Reverts can take hours (CI runs -> Autopilot evaluates -> revert lands),
# so use a wider lookback than the breakage blame check.
REVERT_LOOKBACK_SECS: int = 14400  # 4 hours

# After tentative -> confirmed promotion, re-query Phabricator one more time
# after a short delay before firing the alert. The two-step state machine
# catches REVERTED flips that span >=10 minutes (one polling interval), but
# some flips persist long enough to be observed twice and still settle back
# to CLOSED before any actual revert commit lands. The delayed re-check
# adds a final observation gap to filter those out.
REVERT_CONFIRMATION_RECHECK_DELAY_SECS: int = 90

SCUBA_SOURCE: str = "merge_resolution_blame_checker"

ALERT_TYPE_BLAMED: str = "merge_resolved_then_blamed"
ALERT_TYPE_REVERTED: str = "merge_resolved_then_reverted"
_VALID_ALERT_TYPES: set[str] = {ALERT_TYPE_BLAMED, ALERT_TYPE_REVERTED}

# Revert alerts use two-step confirmation: a diff must be observed as REVERTED
# on two consecutive runs before alerting. The first sighting is logged with
# alert_state="tentative" (no alert), and on the second sighting we promote to
# "confirmed" and fire the alert. This avoids false positives from transient
# REVERTED flips on Phabricator (e.g., revert-hammer attempts that abort and
# leave the diff back at CLOSED with no actual revert commit landed).
ALERT_STATE_TENTATIVE: str = "tentative"
ALERT_STATE_CONFIRMED: str = "confirmed"


def _get_merge_resolved_diffs_sql(lookback_secs: int) -> str:
    """SQL JOIN to find merge-resolved pushrebases and their diff IDs."""
    return f"""
        SELECT
            mononoke_land_service.`changeset_id` AS cs_id,
            mononoke_new_commit.`diff_id` AS the_diff_id,
            mononoke_land_service.`merge_resolved_count` AS merge_count,
            mononoke_land_service.`merge_resolved_paths` AS merge_paths,
            mononoke_land_service.`repo_name` AS repo
        FROM mononoke_land_service
        JOIN mononoke_new_commit
            ON mononoke_land_service.`changeset_id`
                = mononoke_new_commit.`changeset_id`
        WHERE
            NOW() - {lookback_secs}
                <= mononoke_land_service.`time`
            AND mononoke_land_service.`time` <= NOW()
            AND NOW() - {lookback_secs}
                <= mononoke_new_commit.`time`
            AND mononoke_new_commit.`time` <= NOW()
            AND mononoke_land_service.`merge_resolved_count` > 0
            AND mononoke_new_commit.`diff_id` IS NOT NULL
    """


def _get_blame_check_sql(diff_ids: list[str]) -> str:
    """SQL to check if any diffs were blamed for trunk breakages.

    Batches all diff IDs into a single query using CONTAINS_ANY on the
    potential_blame_diff_nums tagset column.
    """
    for did in diff_ids:
        if not did.isdigit():
            raise ValueError(f"Invalid diff ID (expected numeric): {did!r}")
    diff_id_list = ", ".join(f"'{did}'" for did in diff_ids)
    conditions = f"CONTAINS_ANY(`potential_blame_diff_nums`, ARRAY({diff_id_list}))"
    return f"""
        SELECT
            `breakage_id` AS the_breakage_id,
            `diagnosis_result_source` AS the_source,
            `potential_blame_diff_nums` AS the_blame_diffs
        FROM fbsource_breakage_quick_diagnosis_results
        WHERE
            `time` >= NOW() - {BLAME_LOOKBACK_SECS}
            AND `time` <= NOW()
            AND ({conditions})
        LIMIT 50
    """


def _check_diffs_reverted(diff_ids: list[str]) -> list[str]:
    """Check which diffs have been reverted via Phabricator GraphQL.

    Uses the batch API to query all diffs in a single GraphQL request.
    Uses diff_reader_bot() for service auth (works in Chronos cron jobs
    where there is no interactive user session or .arcrc file).

    Returns diff IDs that have REVERTED status.
    """
    auth = PhabricatorAuthStrategyFactory.diff_reader_bot()
    client = PhabricatorGraphQLClientBase(auth, SCUBA_SOURCE)

    reverted: list[str] = []
    try:
        results = get_phabricator_diffs_with_custom_return_fields(
            client,
            phabricator_diff_numbers=diff_ids,
            return_fields="phabricator_diff_status_enum",
        )
        for diff_id, result in zip(diff_ids, results):
            status = result.get("phabricator_diff_status_enum", "")
            if status == PhabricatorDiffStatus.REVERTED.name:
                reverted.append(diff_id)
                logger.info("Diff D%s has REVERTED status", diff_id)
    except Exception:
        logger.exception(
            "Failed to batch-query Phabricator for %d diffs", len(diff_ids)
        )
    return reverted


async def _query_scuba(
    sql: str, table: str, user_name: str, user_id: int
) -> list[dict[str, ResultType]]:
    """Execute a Scuba SQL query and return results.

    Returns an empty list when the query returns no rows (e.g. empty table).
    query_sql_as_dict raises ValueError when the underlying SQLQueryResult
    is not valid, which happens when the Scuba table has no matching data.
    """
    try:
        return await query_sql_as_dict(
            table=table,
            sql=sql,
            source=SCUBA_SOURCE,
            user_name=user_name,
            user_id=user_id,
        )
    except ValueError:
        logger.debug("Scuba query returned no results for table %s", table)
        return []


async def check_merge_resolution_blames(
    user_name: str, uid: int, dry_run: bool = False
) -> int:
    """
    Check if any merge-resolved diffs were blamed for trunk breakages.

    Returns the number of matches found.
    """
    # Step 1: Find merge-resolved diffs
    logger.info(
        "Querying merge-resolved pushrebases (last %ds)...",
        MERGE_RESOLUTION_LOOKBACK_SECS,
    )
    merge_resolved = await _query_scuba(
        _get_merge_resolved_diffs_sql(MERGE_RESOLUTION_LOOKBACK_SECS),
        "mononoke_land_service",
        user_name,
        uid,
    )

    if not merge_resolved:
        logger.info("No merge-resolved pushrebases found in the lookback window.")
        return 0

    logger.info(
        "Found %d merge-resolved pushrebases. Checking for trunk breakage blame...",
        len(merge_resolved),
    )

    # Step 2: Batch-check all diff IDs against trunk breakage blame
    diff_id_to_entry: dict[str, dict[str, ResultType]] = {}
    for entry in merge_resolved:
        diff_id = str(entry.get("the_diff_id", ""))
        if diff_id:
            diff_id_to_entry[diff_id] = entry

    if not diff_id_to_entry:
        logger.info("No diff IDs found in merge-resolved entries.")
        return 0

    logger.info(
        "Checking %d diff IDs against trunk breakage blame...", len(diff_id_to_entry)
    )

    blame_results = await _query_scuba(
        _get_blame_check_sql(list(diff_id_to_entry.keys())),
        "fbsource_breakage_quick_diagnosis_results",
        user_name,
        uid,
    )

    matches: list[dict[str, str]] = []
    for blame in blame_results:
        breakage_id = str(blame.get("the_breakage_id", ""))
        blame_diffs_raw = str(blame.get("the_blame_diffs", ""))
        # Parse tagset string (e.g. '["123", "456"]') into a set for exact matching
        blame_diff_set = {
            d.strip().strip("'\"")
            for d in blame_diffs_raw.strip("[]").split(",")
            if d.strip()
        }

        # Find which of our diff IDs appear in this breakage's blame list
        for diff_id, entry in diff_id_to_entry.items():
            if diff_id in blame_diff_set:
                cs_id = str(entry.get("cs_id", ""))
                repo = str(entry.get("repo", ""))
                merge_paths = str(entry.get("merge_paths", ""))
                merge_count = str(entry.get("merge_count", ""))

                match_info = {
                    "diff_id": diff_id,
                    "changeset_id": cs_id,
                    "repo": repo,
                    "merge_resolved_count": merge_count,
                    "merge_resolved_paths": merge_paths,
                    "breakage_id": breakage_id,
                }
                matches.append(match_info)
                logger.warning(
                    "MATCH: Merge-resolved diff D%s (repo=%s, paths=%s) "
                    "was blamed for trunk breakage %s",
                    diff_id,
                    repo,
                    merge_paths,
                    breakage_id,
                )

    if matches:
        logger.warning(
            "Found %d merge-resolved diffs blamed for trunk breakages!",
            len(matches),
        )
        if not dry_run:
            _log_matches_to_scuba(matches, ALERT_TYPE_BLAMED)
    else:
        logger.info("No merge-resolved diffs found in trunk breakage blame lists.")

    return len(matches)


SCUBA_OUTPUT_TABLE: str = "mononoke_merge_resolution_alerts"


def _log_matches_to_scuba(
    matches: list[dict[str, str]],
    alert_type: str,
    alert_state: str = ALERT_STATE_CONFIRMED,
) -> None:
    """Write alert events to a dedicated Scuba table for OneDetection alerting.

    Scuba write failures are logged but not re-raised because the primary
    alerting mechanism is the non-zero exit code for Chronos. Failing to
    write to Scuba should not prevent the script from reporting the match.

    `alert_state` distinguishes tentative sightings (logged but not alerted)
    from confirmed alerts (fire OneDetection). Only REVERTED uses tentative.
    """
    try:
        with ScubaData(SCUBA_OUTPUT_TABLE) as scuba:
            for match in matches:
                sample = ScubaData.Sample()
                sample.add_normal("diff_id", match["diff_id"])
                sample.add_normal("changeset_id", match["changeset_id"])
                sample.add_normal("repo", match["repo"])
                sample.add_normal("merge_resolved_paths", match["merge_resolved_paths"])
                sample.add_normal("alert_type", alert_type)
                sample.add_normal("alert_state", alert_state)
                if "breakage_id" in match:
                    sample.add_normal("breakage_id", match["breakage_id"])
                sample.add_int(
                    "merge_resolved_count",
                    int(match.get("merge_resolved_count", "0")),
                )
                scuba.addSample(sample)
        logger.info(
            "Logged %d %s/%s matches to Scuba table %s",
            len(matches),
            alert_type,
            alert_state,
            SCUBA_OUTPUT_TABLE,
        )
    except Exception:
        logger.exception("Failed to log to Scuba")


async def _get_already_alerted_diffs(
    user_name: str,
    uid: int,
    alert_type: str,
    lookback_secs: int,
    alert_state: str | None = None,
) -> set[str]:
    """Query mononoke_merge_resolution_alerts for diffs we already alerted on.

    Prevents duplicate alerts when the same diff appears in multiple
    pipeline runs within the lookback window.

    When `alert_state` is provided, only rows matching that state are
    returned. Rows with a NULL/missing alert_state are treated as
    `confirmed` for backward compatibility with rows written before the
    two-step confirmation flow was introduced.
    """
    if alert_type not in _VALID_ALERT_TYPES:
        raise ValueError(f"Invalid alert_type: {alert_type!r}")
    state_clause = ""
    if alert_state == ALERT_STATE_CONFIRMED:
        # Treat NULL/empty alert_state as confirmed (legacy rows)
        state_clause = (
            f" AND (`alert_state` = '{ALERT_STATE_CONFIRMED}'"
            f" OR `alert_state` IS NULL OR `alert_state` = '')"
        )
    elif alert_state is not None:
        state_clause = f" AND `alert_state` = '{alert_state}'"
    sql = f"""
        SELECT `diff_id` AS the_diff_id
        FROM {SCUBA_OUTPUT_TABLE}
        WHERE
            `time` >= NOW() - {lookback_secs}
            AND `time` <= NOW()
            AND `alert_type` = '{alert_type}'
            {state_clause}
    """
    try:
        results = await _query_scuba(sql, SCUBA_OUTPUT_TABLE, user_name, uid)
        return {str(r.get("the_diff_id", "")) for r in results if r.get("the_diff_id")}
    except Exception:
        logger.exception(
            "Failed to query already-alerted diffs, proceeding without dedup"
        )
        return set()


async def _verify_still_reverted(
    matches: list[dict[str, str]],
) -> list[dict[str, str]]:
    """Re-query Phab after a delay to confirm REVERTED status persists.

    Returns the subset of `matches` whose diffs are still REVERTED on
    Phab after `REVERT_CONFIRMATION_RECHECK_DELAY_SECS` seconds. Diffs
    that have flipped back to non-REVERTED are dropped (treated as
    transient flaps, not real reverts).
    """
    diff_ids = [m["diff_id"] for m in matches]
    logger.info(
        "Re-checking %d candidate confirmed reverts after %ds delay...",
        len(diff_ids),
        REVERT_CONFIRMATION_RECHECK_DELAY_SECS,
    )
    await asyncio.sleep(REVERT_CONFIRMATION_RECHECK_DELAY_SECS)
    still_reverted = set(_check_diffs_reverted(diff_ids))
    survived = [m for m in matches if m["diff_id"] in still_reverted]
    dropped_ids = sorted(set(diff_ids) - still_reverted)
    if dropped_ids:
        logger.warning(
            "Dropped %d confirmed-revert candidates that settled back to "
            "non-REVERTED during re-check: %s",
            len(dropped_ids),
            ", ".join(f"D{d}" for d in dropped_ids),
        )
    return survived


async def check_merge_resolution_reverts(
    user_name: str, uid: int, dry_run: bool = False
) -> int:
    """Check if any merge-resolved diffs were reverted.

    Uses a wider lookback (4h) because reverts take time after initial land.
    Queries Phabricator GraphQL for diff status.

    Returns the number of reverted merge-resolved diffs found.
    """
    logger.info(
        "Querying merge-resolved pushrebases (last %ds) for revert check...",
        REVERT_LOOKBACK_SECS,
    )
    merge_resolved = await _query_scuba(
        _get_merge_resolved_diffs_sql(REVERT_LOOKBACK_SECS),
        "mononoke_land_service",
        user_name,
        uid,
    )

    if not merge_resolved:
        logger.info("No merge-resolved pushrebases found for revert check.")
        return 0

    # Build diff_id -> entry map, deduplicating by diff_id
    diff_id_to_entry: dict[str, dict[str, ResultType]] = {}
    for entry in merge_resolved:
        diff_id = str(entry.get("the_diff_id", ""))
        if diff_id:
            diff_id_to_entry[diff_id] = entry

    if not diff_id_to_entry:
        return 0

    # Two-step confirmation:
    #   - Skip diffs we already confirmed (already fired alert).
    #   - Diffs previously seen as `tentative` will be promoted to `confirmed`
    #     (and alert) if Phab still reports REVERTED on this run.
    #   - New REVERTED sightings are logged as `tentative` (no alert).
    # This avoids alerting on transient REVERTED flips (e.g., revert-hammer
    # attempts that abort and leave the diff back at CLOSED).
    already_confirmed = await _get_already_alerted_diffs(
        user_name,
        uid,
        ALERT_TYPE_REVERTED,
        REVERT_LOOKBACK_SECS,
        alert_state=ALERT_STATE_CONFIRMED,
    )
    already_tentative = await _get_already_alerted_diffs(
        user_name,
        uid,
        ALERT_TYPE_REVERTED,
        REVERT_LOOKBACK_SECS,
        alert_state=ALERT_STATE_TENTATIVE,
    )
    unchecked = {
        k: v for k, v in diff_id_to_entry.items() if k not in already_confirmed
    }

    if not unchecked:
        logger.info(
            "All %d merge-resolved diffs already confirmed, skipping.",
            len(diff_id_to_entry),
        )
        return 0

    logger.info(
        "Checking %d diff IDs for revert status "
        "(%d already confirmed, %d tentative)...",
        len(unchecked),
        len(already_confirmed),
        len(already_tentative),
    )

    reverted_ids = _check_diffs_reverted(list(unchecked.keys()))

    confirmed_matches: list[dict[str, str]] = []
    tentative_matches: list[dict[str, str]] = []
    for diff_id in reverted_ids:
        entry = unchecked[diff_id]
        match_info = {
            "diff_id": diff_id,
            "changeset_id": str(entry.get("cs_id", "")),
            "repo": str(entry.get("repo", "")),
            "merge_resolved_count": str(entry.get("merge_count", "")),
            "merge_resolved_paths": str(entry.get("merge_paths", "")),
        }
        if diff_id in already_tentative:
            confirmed_matches.append(match_info)
            logger.warning(
                "REVERT CONFIRMED: Merge-resolved diff D%s "
                "(repo=%s, paths=%s) reverted on two consecutive runs",
                diff_id,
                match_info["repo"],
                match_info["merge_resolved_paths"],
            )
        else:
            tentative_matches.append(match_info)
            logger.info(
                "REVERT TENTATIVE: Merge-resolved diff D%s (repo=%s, paths=%s) "
                "reported REVERTED — awaiting second observation",
                diff_id,
                match_info["repo"],
                match_info["merge_resolved_paths"],
            )

    if not dry_run:
        if tentative_matches:
            _log_matches_to_scuba(
                tentative_matches, ALERT_TYPE_REVERTED, ALERT_STATE_TENTATIVE
            )
        if confirmed_matches:
            confirmed_matches = await _verify_still_reverted(confirmed_matches)
        if confirmed_matches:
            _log_matches_to_scuba(
                confirmed_matches, ALERT_TYPE_REVERTED, ALERT_STATE_CONFIRMED
            )

    if confirmed_matches:
        logger.warning(
            "Found %d confirmed reverted merge-resolved diffs!",
            len(confirmed_matches),
        )
    else:
        logger.info(
            "No confirmed reverted merge-resolved diffs "
            "(%d tentative awaiting confirmation).",
            len(tentative_matches),
        )

    # Only confirmed reverts contribute to the non-zero exit code / alert.
    return len(confirmed_matches)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Check if merge-resolved pushrebase diffs were blamed "
            "for trunk breakages or reverted"
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run checks but don't emit alerts",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    # Resolve oncall identity once for both checks (Scuba auth)
    with OncallThriftClient() as client:
        oncall_result = client.getCurrentOncallForRotationByShortName(
            "scm_server_infra"
        )
    uid = oncall_result.uid
    user_name = uid_to_unixname(uid)

    start = time.monotonic()

    blame_count = asyncio.run(
        check_merge_resolution_blames(user_name, uid, dry_run=args.dry_run)
    )
    revert_count = asyncio.run(
        check_merge_resolution_reverts(user_name, uid, dry_run=args.dry_run)
    )

    elapsed = time.monotonic() - start

    logger.info(
        "Completed in %.1fs. Blame matches: %d, Revert matches: %d",
        elapsed,
        blame_count,
        revert_count,
    )

    total = blame_count + revert_count
    if total > 0 and not args.dry_run:
        sys.exit(1)


if __name__ == "__main__":
    main()
