/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::collections::HashSet;

use anyhow::Result;
use anyhow::anyhow;
use bookmarks::BookmarkKey;
use bookmarks::BookmarkKind;
use bookmarks::BookmarkTransactionError;
use bookmarks::BookmarkUpdateReason;
use context::CoreContext;
use dbbookmarks::transaction::AddBookmarkLog;
use dbbookmarks::transaction::DeleteBookmarkIf;
use dbbookmarks::transaction::FindMaxBookmarkLogId;
use dbbookmarks::transaction::InsertBookmarks;
use dbbookmarks::transaction::UpdateBookmark;
use mononoke_types::ChangesetId;
use mononoke_types::RepositoryId;
use mononoke_types::Timestamp;
use sql_ext::Connection;
use sql_ext::Transaction as SqlTransaction;

/// A bookmark operation to be executed atomically in a multi-repo transaction.
enum BookmarkOp {
    Update {
        repo_id: RepositoryId,
        bookmark: BookmarkKey,
        old_cs_id: ChangesetId,
        new_cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    },
    Create {
        repo_id: RepositoryId,
        bookmark: BookmarkKey,
        cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    },
    Delete {
        repo_id: RepositoryId,
        bookmark: BookmarkKey,
        old_cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    },
}

impl BookmarkOp {
    fn repo_id(&self) -> RepositoryId {
        match self {
            Self::Update { repo_id, .. }
            | Self::Create { repo_id, .. }
            | Self::Delete { repo_id, .. } => *repo_id,
        }
    }

    fn bookmark(&self) -> &BookmarkKey {
        match self {
            Self::Update { bookmark, .. }
            | Self::Create { bookmark, .. }
            | Self::Delete { bookmark, .. } => bookmark,
        }
    }

    /// Execute this operation within a SQL transaction.
    ///
    /// Pushes a log entry and runs the appropriate SQL query.
    /// Returns `LogicError` if the CAS check fails.
    async fn execute(
        &self,
        txn: SqlTransaction,
        log: &mut TransactionLog,
    ) -> Result<SqlTransaction, BookmarkTransactionError> {
        match self {
            Self::Update {
                repo_id,
                bookmark,
                old_cs_id,
                new_cs_id,
                reason,
            } => {
                let log_id = log.push(
                    *repo_id,
                    bookmark,
                    Some(*old_cs_id),
                    Some(*new_cs_id),
                    *reason,
                );
                let (txn, result) = UpdateBookmark::query_with_transaction(
                    txn,
                    repo_id,
                    &Some(log_id),
                    bookmark.name(),
                    bookmark.category(),
                    old_cs_id,
                    new_cs_id,
                    BookmarkKind::ALL_PUBLISHING,
                )
                .await?;
                if result.affected_rows() != 1 {
                    return Err(BookmarkTransactionError::LogicError);
                }
                Ok(txn)
            }
            Self::Create {
                repo_id,
                bookmark,
                cs_id,
                reason,
            } => {
                let log_id = log.push(*repo_id, bookmark, None, Some(*cs_id), *reason);
                let data = [(
                    repo_id,
                    &Some(log_id),
                    bookmark.name(),
                    bookmark.category(),
                    cs_id,
                    &BookmarkKind::PullDefaultPublishing,
                )];
                let (txn, result) = InsertBookmarks::query_with_transaction(txn, &data[..]).await?;
                if result.affected_rows() != 1 {
                    return Err(BookmarkTransactionError::LogicError);
                }
                Ok(txn)
            }
            Self::Delete {
                repo_id,
                bookmark,
                old_cs_id,
                reason,
            } => {
                log.push(*repo_id, bookmark, Some(*old_cs_id), None, *reason);
                let (txn, result) = DeleteBookmarkIf::query_with_transaction(
                    txn,
                    repo_id,
                    bookmark.name(),
                    bookmark.category(),
                    old_cs_id,
                )
                .await?;
                if result.affected_rows() != 1 {
                    return Err(BookmarkTransactionError::LogicError);
                }
                Ok(txn)
            }
        }
    }
}

/// Accumulates log entries and assigns sequential IDs per repo.
struct TransactionLog {
    next_log_ids: HashMap<RepositoryId, u64>,
    entries: Vec<LogEntry>,
}

struct LogEntry {
    id: u64,
    repo_id: RepositoryId,
    bookmark: BookmarkKey,
    old: Option<ChangesetId>,
    new: Option<ChangesetId>,
    reason: BookmarkUpdateReason,
}

impl TransactionLog {
    fn new(next_log_ids: HashMap<RepositoryId, u64>) -> Self {
        Self {
            next_log_ids,
            entries: Vec::new(),
        }
    }

    fn push(
        &mut self,
        repo_id: RepositoryId,
        bookmark: &BookmarkKey,
        old: Option<ChangesetId>,
        new: Option<ChangesetId>,
        reason: BookmarkUpdateReason,
    ) -> u64 {
        let next_id = self.next_log_ids.entry(repo_id).or_insert(1);
        let id = *next_id;
        self.entries.push(LogEntry {
            id,
            repo_id,
            bookmark: bookmark.clone(),
            old,
            new,
            reason,
        });
        *next_id += 1;
        id
    }

    /// Write all accumulated log entries into the SQL transaction.
    async fn write(self, mut txn: SqlTransaction) -> Result<SqlTransaction> {
        let timestamp = Timestamp::now();
        for entry in &self.entries {
            let data = [(
                &entry.id,
                &entry.repo_id,
                entry.bookmark.name(),
                entry.bookmark.category(),
                &entry.old,
                &entry.new,
                &entry.reason,
                &timestamp,
            )];
            txn = AddBookmarkLog::query_with_transaction(txn, &data[..])
                .await?
                .0;
        }
        Ok(txn)
    }
}

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
    ctx: CoreContext,
    write_connection: Connection,
    /// Track (repo_id, bookmark) pairs to prevent duplicates.
    seen: HashSet<(RepositoryId, BookmarkKey)>,
    ops: Vec<BookmarkOp>,
}

impl MultiRepoBookmarksTransaction {
    pub fn new(ctx: CoreContext, write_connection: Connection) -> Self {
        Self {
            ctx,
            write_connection,
            seen: HashSet::new(),
            ops: Vec::new(),
        }
    }

    /// Add an operation, ensuring each (repo_id, bookmark) pair is used at most once.
    fn push(&mut self, op: BookmarkOp) -> Result<()> {
        if !self.seen.insert((op.repo_id(), op.bookmark().clone())) {
            return Err(anyhow!(
                "({}, {}) bookmark was already used in this transaction",
                op.repo_id(),
                op.bookmark()
            ));
        }
        self.ops.push(op);
        Ok(())
    }

    pub fn update(
        &mut self,
        repo_id: RepositoryId,
        bookmark: &BookmarkKey,
        new_cs_id: ChangesetId,
        old_cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    ) -> Result<()> {
        self.push(BookmarkOp::Update {
            repo_id,
            bookmark: bookmark.clone(),
            old_cs_id,
            new_cs_id,
            reason,
        })
    }

    pub fn create(
        &mut self,
        repo_id: RepositoryId,
        bookmark: &BookmarkKey,
        cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    ) -> Result<()> {
        self.push(BookmarkOp::Create {
            repo_id,
            bookmark: bookmark.clone(),
            cs_id,
            reason,
        })
    }

    pub fn delete(
        &mut self,
        repo_id: RepositoryId,
        bookmark: &BookmarkKey,
        old_cs_id: ChangesetId,
        reason: BookmarkUpdateReason,
    ) -> Result<()> {
        self.push(BookmarkOp::Delete {
            repo_id,
            bookmark: bookmark.clone(),
            old_cs_id,
            reason,
        })
    }

    /// Commit all accumulated operations in a single SQL transaction.
    ///
    /// Returns Success if all CAS operations pass, or CasFailure if any
    /// CAS check fails (entire transaction is rolled back).
    pub async fn commit(self) -> Result<MultiRepoBookmarksTransactionResult> {
        if self.ops.is_empty() {
            return Ok(MultiRepoBookmarksTransactionResult::Success);
        }

        let repo_ids: HashSet<_> = self.ops.iter().map(|op| op.repo_id()).collect();

        let txn = self
            .write_connection
            .start_transaction(self.ctx.sql_query_telemetry())
            .await?;

        let (mut txn, next_log_ids) = find_next_log_ids(txn, &repo_ids).await?;
        let mut log = TransactionLog::new(next_log_ids);

        // Execute all operations in one SQL transaction
        let result: Result<_, BookmarkTransactionError> = async {
            for op in &self.ops {
                txn = op.execute(txn, &mut log).await?;
            }
            Ok(txn)
        }
        .await;

        match result {
            Ok(txn) => {
                let txn = log
                    .write(txn)
                    .await
                    .map_err(BookmarkTransactionError::RetryableError)?;
                txn.commit().await?;
                Ok(MultiRepoBookmarksTransactionResult::Success)
            }
            Err(BookmarkTransactionError::LogicError) => {
                Ok(MultiRepoBookmarksTransactionResult::CasFailure)
            }
            Err(BookmarkTransactionError::RetryableError(err)) => Err(err),
            Err(BookmarkTransactionError::Other(err)) => Err(err),
        }
    }
}

/// Find the next bookmark update log ID for each repo within the transaction.
async fn find_next_log_ids(
    mut txn: SqlTransaction,
    repo_ids: &HashSet<RepositoryId>,
) -> Result<(SqlTransaction, HashMap<RepositoryId, u64>)> {
    let mut next_ids = HashMap::new();
    for &repo_id in repo_ids {
        let (txn_, max_id_entries) =
            FindMaxBookmarkLogId::query_with_transaction(txn, &repo_id).await?;
        txn = txn_;
        let next_id = match &max_id_entries[..] {
            [(None,)] => 1,
            [(Some(max_existing),)] => *max_existing + 1,
            _ => {
                return Err(anyhow!(
                    "FindMaxBookmarkLogId returned multiple entries for repo {}: {:?}",
                    repo_id,
                    max_id_entries
                ));
            }
        };
        next_ids.insert(repo_id, next_id);
    }
    Ok((txn, next_ids))
}
