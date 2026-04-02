/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::time::Duration;

use moka::sync::Cache;
use mononoke_types::ChangesetId;

use crate::EligibleChangesetInfo;

/// Bounded, TTL-backed in-memory cache of config-stable changeset inspection results.
///
/// Entries are keyed by `ChangesetId`. `Some(info)` means the changeset is
/// eligible; `None` means it was inspected and found ineligible. Both positive
/// and negative results are cached.
///
/// Errors are never cached — the caller should only insert successful results.
pub struct ChangesetEligibilityCache {
    entries: Cache<ChangesetId, Option<EligibleChangesetInfo>>,
}

impl ChangesetEligibilityCache {
    pub fn new(max_entries: u64, ttl: Duration) -> Self {
        Self {
            entries: Cache::builder()
                .max_capacity(max_entries)
                // Using `time_to_idle`, which will refresh the TTL on reads.
                // A cached entry will be expired after the specified duration
                // past from get or insert.
                .time_to_idle(ttl)
                .build(),
        }
    }

    /// Pure cache lookup. Returns `Some(cached_value)` on hit, `None` on miss.
    pub fn lookup(&self, cs_id: &ChangesetId) -> Option<Option<EligibleChangesetInfo>> {
        self.entries.get(cs_id)
    }

    /// Insert a result into the cache.
    pub fn insert(&self, cs_id: ChangesetId, value: Option<EligibleChangesetInfo>) {
        self.entries.insert(cs_id, value);
    }

    /// Synchronous cache lookup and insertion. Used in the
    /// `matching_ancestors_stream` predicate where the changeset is already
    /// loaded and inspection is synchronous.
    pub fn get_or_insert_sync(
        &self,
        cs_id: ChangesetId,
        inspector: impl FnOnce() -> Option<EligibleChangesetInfo>,
    ) -> Option<EligibleChangesetInfo> {
        if let Some(entry) = self.entries.get(&cs_id) {
            return entry;
        }
        let result = inspector();
        self.entries.insert(cs_id, result.clone());
        result
    }
}
