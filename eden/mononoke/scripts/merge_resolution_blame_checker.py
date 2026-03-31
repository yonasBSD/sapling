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
from rfe.py.lib.sql import query_sql_as_dict, ResultType
from rfe.scubadata.scubadata_py3 import ScubaData


logger: logging.Logger = logging.getLogger(__name__)

# How far back to look for merge-resolved pushrebases (seconds).
# Use 1200s (20 min) to overlap with the 10-min run interval.
MERGE_RESOLUTION_LOOKBACK_SECS: int = 1200

# How far back to look for trunk breakage blame (seconds).
# Trunk CI may take hours to detect breakage, so use a wider window.
BLAME_LOOKBACK_SECS: int = 14400  # 4 hours

SCUBA_SOURCE: str = "merge_resolution_blame_checker"


def _get_merge_resolved_diffs_sql() -> str:
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
            NOW() - {MERGE_RESOLUTION_LOOKBACK_SECS}
                <= mononoke_land_service.`time`
            AND mononoke_land_service.`time` <= NOW()
            AND NOW() - {MERGE_RESOLUTION_LOOKBACK_SECS}
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


async def _query_scuba(
    sql: str, table: str, user_name: str, user_id: int
) -> list[dict[str, ResultType]]:
    """Execute a Scuba SQL query and return results."""
    return await query_sql_as_dict(
        table=table,
        sql=sql,
        source=SCUBA_SOURCE,
        user_name=user_name,
        user_id=user_id,
    )


async def check_merge_resolution_blames(dry_run: bool = False) -> int:
    """
    Check if any merge-resolved diffs were blamed for trunk breakages.

    Returns the number of matches found.
    """
    # Use the current scm_server_infra oncall's identity for Scuba auth.
    # This works in Chronos/cron where there's no interactive user session.
    with OncallThriftClient() as client:
        oncall_result = client.getCurrentOncallForRotationByShortName(
            "scm_server_infra"
        )
    uid = oncall_result.uid
    user_name = uid_to_unixname(uid)

    # Step 1: Find merge-resolved diffs
    logger.info(
        "Querying merge-resolved pushrebases (last %ds)...",
        MERGE_RESOLUTION_LOOKBACK_SECS,
    )
    merge_resolved = await _query_scuba(
        _get_merge_resolved_diffs_sql(),
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
            _log_matches_to_scuba(matches)
    else:
        logger.info("No merge-resolved diffs found in trunk breakage blame lists.")

    return len(matches)


SCUBA_OUTPUT_TABLE: str = "mononoke_merge_resolution_alerts"


def _log_matches_to_scuba(matches: list[dict[str, str]]) -> None:
    """Write match events to a dedicated Scuba table for OneDetection alerting.

    Scuba write failures are logged but not re-raised because the primary
    alerting mechanism is the non-zero exit code for Chronos. Failing to
    write to Scuba should not prevent the script from reporting the match.
    """
    try:
        with ScubaData(SCUBA_OUTPUT_TABLE) as scuba:
            for match in matches:
                sample = ScubaData.Sample()
                sample.add_normal("diff_id", match["diff_id"])
                sample.add_normal("changeset_id", match["changeset_id"])
                sample.add_normal("repo", match["repo"])
                sample.add_normal("merge_resolved_paths", match["merge_resolved_paths"])
                sample.add_normal("breakage_id", match["breakage_id"])
                sample.add_normal("alert_type", "merge_resolved_then_blamed")
                sample.add_int(
                    "merge_resolved_count",
                    int(match.get("merge_resolved_count", "0")),
                )
                scuba.addSample(sample)
        logger.info(
            "Logged %d matches to Scuba table %s", len(matches), SCUBA_OUTPUT_TABLE
        )
    except Exception:
        logger.exception("Failed to log to Scuba")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check if merge-resolved pushrebase diffs were blamed for trunk breakages",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run checks but don't emit ODS counters",
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

    start = time.monotonic()
    match_count = asyncio.run(check_merge_resolution_blames(dry_run=args.dry_run))
    elapsed = time.monotonic() - start

    logger.info(
        "Completed in %.1fs. Matches: %d",
        elapsed,
        match_count,
    )

    # Exit with non-zero code when matches are found so Chronos
    # job failure alerting can trigger oncall notification.
    if match_count > 0 and not args.dry_run:
        sys.exit(1)


if __name__ == "__main__":
    main()
