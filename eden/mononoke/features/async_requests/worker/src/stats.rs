/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::time::Duration;

use async_requests::AsyncMethodRequestQueue;
use async_requests::types::RequestStatus;
use context::CoreContext;
use mononoke_api::RepositoryId;
use mononoke_types::Timestamp;
use stats::define_stats;
use stats::prelude::*;
use tracing::warn;

const STATS_LOOP_INTERNAL: Duration = Duration::from_mins(5);

const STATUSES: [RequestStatus; 4] = [
    RequestStatus::New,
    RequestStatus::InProgress,
    RequestStatus::Ready,
    RequestStatus::Polled,
];

define_stats! {
    prefix = "async_requests.worker.stats";

    stats_error: timeseries("error"; Count),
    queue_length_by_status: dynamic_singleton_counter("queue.length.{}", (status: String)),
    queue_age_by_status: dynamic_singleton_counter("queue.age_s.{}", (status: String)),
    queue_length_by_repo_and_status: dynamic_singleton_counter("queue.{}.length.{}", (repo_id: String, status: String)),
    queue_age_by_repo_and_status: dynamic_singleton_counter("queue.{}.age_s.{}", (repo_id: String, status: String)),
}

/// Report queue stats for this shard's repo only.
///
/// Each shard reports metrics only for its own repo_id. This avoids
/// cross-shard racing on shared counters and prevents stale values
/// when a shard is reassigned: the counter simply goes absent (no
/// data) rather than being stuck at a stale non-zero value. A dead
/// shard detector should alert on absence of data.
///
/// For the non-sharded code path, `repo_id` is `None` and only the
/// global (non-per-repo) counters are reported.
pub(crate) async fn stats_loop(
    ctx: &CoreContext,
    repo_id: Option<RepositoryId>,
    queue: &AsyncMethodRequestQueue,
) {
    loop {
        let res = queue.get_queue_stats(ctx, true).await;
        let now = Timestamp::now();
        match res {
            Ok(res) => {
                process_queue_length_by_status(ctx, &res);
                process_queue_age_by_status(ctx, now, &res);
                if let Some(repo_id) = &repo_id {
                    process_queue_length_by_repo(ctx, repo_id, &res);
                    process_queue_age_by_repo(ctx, repo_id, now, &res);
                }
            }
            Err(err) => {
                STATS::stats_error.add_value(1);
                warn!("error while getting queue stats, skipping: {:?}", err);
            }
        }

        tokio::time::sleep(STATS_LOOP_INTERNAL).await;
    }
}

fn process_queue_length_by_status(ctx: &CoreContext, res: &requests_table::QueueStats) {
    // Report whatever the DB returns for global stats, then zero out
    // any of the 4 statuses that were absent from the result.
    let mut seen = [false; 4];
    let stats = &res.queue_length_by_status;
    for (status, count) in stats {
        if let Some(idx) = status_index(status) {
            seen[idx] = true;
        }
        STATS::queue_length_by_status.set_value(ctx.fb, *count as i64, (status.to_string(),));
    }

    for (idx, was_seen) in seen.iter().enumerate() {
        if !was_seen {
            STATS::queue_length_by_status.set_value(ctx.fb, 0, (STATUSES[idx].to_string(),));
        }
    }
}

fn process_queue_age_by_status(
    ctx: &CoreContext,
    now: Timestamp,
    res: &requests_table::QueueStats,
) {
    let mut seen = [false; 4];
    let stats = &res.queue_age_by_status;
    for (status, ts) in stats {
        if let Some(idx) = status_index(status) {
            seen[idx] = true;
        }
        let diff = std::cmp::max(now.timestamp_seconds() - ts.timestamp_seconds(), 0);
        STATS::queue_age_by_status.set_value(ctx.fb, diff, (status.to_string(),));
    }

    for (idx, was_seen) in seen.iter().enumerate() {
        if !was_seen {
            STATS::queue_age_by_status.set_value(ctx.fb, 0, (STATUSES[idx].to_string(),));
        }
    }
}

/// Report per-repo queue length for this shard's repo only.
/// If the DB returns no data for a status, we report 0.
fn process_queue_length_by_repo(
    ctx: &CoreContext,
    repo_id: &RepositoryId,
    res: &requests_table::QueueStats,
) {
    let mut seen = [false; 4];
    let repo_id_str = repo_id.to_string();
    let stats = &res.queue_length_by_repo_and_status;
    for (entry, count) in stats {
        if entry.repo_id.as_ref() == Some(repo_id) {
            if let Some(idx) = status_index(&entry.status) {
                seen[idx] = true;
            }
            STATS::queue_length_by_repo_and_status.set_value(
                ctx.fb,
                *count as i64,
                (repo_id_str.clone(), entry.status.to_string()),
            );
        }
    }

    for (idx, was_seen) in seen.iter().enumerate() {
        if !was_seen {
            STATS::queue_length_by_repo_and_status.set_value(
                ctx.fb,
                0,
                (repo_id_str.clone(), STATUSES[idx].to_string()),
            );
        }
    }
}

/// Report per-repo queue age for this shard's repo only.
/// If the DB returns no data for a status, we report 0.
fn process_queue_age_by_repo(
    ctx: &CoreContext,
    repo_id: &RepositoryId,
    now: Timestamp,
    res: &requests_table::QueueStats,
) {
    let mut seen = [false; 4];
    let repo_id_str = repo_id.to_string();
    let stats = &res.queue_age_by_repo_and_status;
    for (entry, ts) in stats {
        if entry.repo_id.as_ref() == Some(repo_id) {
            if let Some(idx) = status_index(&entry.status) {
                seen[idx] = true;
            }
            let diff = std::cmp::max(now.timestamp_seconds() - ts.timestamp_seconds(), 0);
            STATS::queue_age_by_repo_and_status.set_value(
                ctx.fb,
                diff,
                (repo_id_str.clone(), entry.status.to_string()),
            );
        }
    }

    for (idx, was_seen) in seen.iter().enumerate() {
        if !was_seen {
            STATS::queue_age_by_repo_and_status.set_value(
                ctx.fb,
                0,
                (repo_id_str.clone(), STATUSES[idx].to_string()),
            );
        }
    }
}

fn status_index(status: &RequestStatus) -> Option<usize> {
    STATUSES.iter().position(|s| s == status)
}
