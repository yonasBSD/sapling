/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::AtomicU64;
use std::sync::atomic::Ordering;

use crate::fetch_cause::FetchCause;
use crate::fetch_mode::FetchMode;

/// A context for a fetch operation.
/// The structure is extendable to support more context in the future
/// (e.g. cause of the fetch, etc.)
#[derive(Debug, Clone)]
pub struct FetchContext {
    mode: FetchMode,
    cause: FetchCause,

    local_fetch_count: Arc<AtomicU64>,
    remote_fetch_count: Arc<AtomicU64>,

    fetch_from_cas_attempted: Arc<AtomicBool>,

    /// When true, LFS files should be skipped during fetch (not resolved).
    /// This is useful for prefetch operations where we don't want to waste
    /// bandwidth fetching large LFS blobs.
    skip_lfs: bool,
}

impl FetchContext {
    pub fn new(mode: FetchMode) -> Self {
        Self::new_with_mode_and_cause(mode, FetchCause::Unspecified)
    }

    pub fn sapling_default() -> Self {
        Self::new_with_mode_and_cause(FetchMode::AllowRemote, FetchCause::SaplingUnknown)
    }

    pub fn sapling_prefetch() -> Self {
        Self::new_with_mode_and_cause(
            FetchMode::AllowRemote | FetchMode::IGNORE_RESULT,
            FetchCause::SaplingPrefetch,
        )
    }

    pub fn new_with_cause(cause: FetchCause) -> Self {
        Self::new_with_mode_and_cause(FetchMode::AllowRemote, cause)
    }

    pub fn new_with_mode_and_cause(mode: FetchMode, cause: FetchCause) -> Self {
        Self {
            mode,
            cause,
            local_fetch_count: Default::default(),
            remote_fetch_count: Default::default(),
            fetch_from_cas_attempted: Default::default(),
            skip_lfs: false,
        }
    }

    pub fn mode(&self) -> FetchMode {
        self.mode
    }

    pub fn cause(&self) -> FetchCause {
        self.cause
    }

    pub fn inc_local(&self, count: u64) {
        self.local_fetch_count.fetch_add(count, Ordering::Relaxed);
    }

    pub fn inc_remote(&self, count: u64) {
        self.remote_fetch_count.fetch_add(count, Ordering::Relaxed);
    }

    pub fn set_fetch_from_cas_attempted(&self, value: bool) {
        self.fetch_from_cas_attempted
            .store(value, Ordering::Relaxed);
    }

    pub fn local_fetch_count(&self) -> u64 {
        self.local_fetch_count.load(Ordering::Relaxed)
    }

    pub fn remote_fetch_count(&self) -> u64 {
        self.remote_fetch_count.load(Ordering::Relaxed)
    }

    pub fn fetch_from_cas_attempted(&self) -> bool {
        self.fetch_from_cas_attempted.load(Ordering::Relaxed)
    }

    pub fn with_skip_lfs(mut self, skip_lfs: bool) -> Self {
        self.skip_lfs = skip_lfs;
        self
    }

    pub fn skip_lfs(&self) -> bool {
        self.skip_lfs
    }
}

impl Default for FetchContext {
    fn default() -> Self {
        Self::sapling_default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_skip_lfs_default_false() {
        let fctx = FetchContext::default();
        assert!(!fctx.skip_lfs());
    }

    #[test]
    fn test_skip_lfs_with_builder() {
        let fctx = FetchContext::new_with_mode_and_cause(
            FetchMode::AllowRemote | FetchMode::IGNORE_RESULT,
            FetchCause::EdenWalkPrefetch,
        )
        .with_skip_lfs(true);

        assert!(fctx.skip_lfs());
        assert!(fctx.mode().ignore_result());
        assert_eq!(fctx.cause(), FetchCause::EdenWalkPrefetch);
    }

    #[test]
    fn test_skip_lfs_preserved_through_clone() {
        let fctx = FetchContext::default().with_skip_lfs(true);
        let cloned = fctx.clone();
        assert!(cloned.skip_lfs());
    }
}
