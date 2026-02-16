/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashSet;

use bookmarks::BookmarkKey;
use mononoke_types::RepositoryId;
use sql_ext::Connection;

/// Result of a multi-repo bookmark transaction.
pub enum MultiRepoBookmarksTransactionResult {
    /// All bookmark updates succeeded.
    Success,
    /// One or more CAS operations failed. No bookmarks were moved.
    CasFailure,
}

impl MultiRepoBookmarksTransactionResult {
    pub fn is_success(&self) -> bool {
        matches!(self, Self::Success)
    }
}

/// A transaction that atomically moves bookmarks across multiple repositories.
///
/// All repos MUST share the same MySQL shard (same write_connection).
/// The transaction accumulates bookmark operations across repos and commits
/// them all in a single SQL transaction.
pub struct MultiRepoBookmarksTransaction {
    #[allow(dead_code)]
    write_connection: Connection,
    /// Track (repo_id, bookmark) pairs to prevent duplicates.
    #[allow(dead_code)]
    seen: HashSet<(RepositoryId, BookmarkKey)>,
}

impl MultiRepoBookmarksTransaction {
    pub fn new(write_connection: Connection) -> Self {
        Self {
            write_connection,
            seen: HashSet::new(),
        }
    }
}
