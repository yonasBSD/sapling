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
#[derive(Clone)]
pub struct ChangesetEligibilityCache {
    entries: Cache<ChangesetId, Option<EligibleChangesetInfo>>,
}

impl std::fmt::Debug for ChangesetEligibilityCache {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ChangesetEligibilityCache")
            .field("entry_count", &self.entries.entry_count())
            .finish()
    }
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

    /// Synchronous cache lookup and insertion with separate hit/miss callbacks.
    /// On cache hit, calls `on_hit` and returns the cached value.
    /// On cache miss, calls `on_miss` to compute the value, inserts it, and returns it.
    pub fn get_or_insert_with(
        &self,
        cs_id: ChangesetId,
        on_hit: impl FnOnce(),
        on_miss: impl FnOnce() -> Option<EligibleChangesetInfo>,
    ) -> Option<EligibleChangesetInfo> {
        if let Some(entry) = self.entries.get(&cs_id) {
            on_hit();
            return entry;
        }
        let result = on_miss();
        self.entries.insert(cs_id, result.clone());
        result
    }
}
