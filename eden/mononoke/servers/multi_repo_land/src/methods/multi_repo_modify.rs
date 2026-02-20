/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::sync::Arc;

use anyhow::Result;
use anyhow::anyhow;
use blobstore::Loadable;
use bonsai_git_mapping::BonsaiGitMappingRef;
use bookmarks::BookmarkKey;
use bookmarks::BookmarkUpdateReason;
use bookmarks::BookmarksRef;
use bookmarks::Freshness;
use bytes::Bytes;
use context::CoreContext;
use dbbookmarks::store::SqlBookmarksRef;
use hook_manager::CrossRepoPushSource;
use hook_manager::PushAuthoredBy;
use hook_manager::manager::HookManagerRef;
use mononoke_types::ChangesetId;
use mononoke_types::NonRootMPath;
use multi_repo_bookmarks_transaction::MultiRepoBookmarksTransaction;
use multi_repo_land_if::ManifestBookmarkModification;
use multi_repo_land_if::MultiRepoLandCasFailure;
use multi_repo_land_if::MultiRepoLandRebaseConflict;
use multi_repo_land_if::MultipleRepoModifyBookmarksParams;
use multi_repo_land_if::MultipleRepoModifyBookmarksResponse;
use multi_repo_land_if::RebaseConflictEntry;
use multi_repo_land_if::RebasedCommitEntry;
use multi_repo_land_if::RepoBookmarkModification;
use multi_repo_land_if::RepoBookmarkModificationSpec;
use multi_repo_land_if::RepoBookmarkResult;
use repo_blobstore::RepoBlobstoreRef;
use repo_identity::RepoIdentityRef;
use source_control as thrift;

use crate::methods::manifest_commit::create_manifest_commit;
use crate::methods::rebase::MergeInfo;
use crate::methods::rebase::RebaseOutcome;
use crate::methods::rebase::rebase_changeset;
use crate::repo::Repo;
use crate::service::MultiRepoLandServiceImpl;

/// CAS failure error with attached merge information for Scuba logging.
#[derive(Debug)]
pub(crate) struct CasFailureWithMergeInfo {
    pub cas_failure: MultiRepoLandCasFailure,
    pub merge_info: MergeInfo,
}

impl std::fmt::Display for CasFailureWithMergeInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.cas_failure.message)
    }
}

impl std::error::Error for CasFailureWithMergeInfo {}

/// Rebase conflict error with attached merge information for Scuba logging.
#[derive(Debug)]
pub(crate) struct RebaseConflictWithMergeInfo {
    pub rebase_conflict: MultiRepoLandRebaseConflict,
    pub merge_info: MergeInfo,
}

impl std::fmt::Display for RebaseConflictWithMergeInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.rebase_conflict.message)
    }
}

impl std::error::Error for RebaseConflictWithMergeInfo {}

/// Resolved representation of a single bookmark modification ready for
/// execution. All commit IDs have been resolved to ChangesetIds.
struct ResolvedBookmarkMod {
    repo_name: String,
    bookmark: BookmarkKey,
    kind: ResolvedModKind,
    pushvars: Option<HashMap<String, Bytes>>,
}

enum ResolvedModKind {
    Create {
        target: ChangesetId,
    },
    Move {
        target: ChangesetId,
        /// The old bookmark position used for the CAS check. Always resolved
        /// eagerly during the resolve step so that handle_cas_failure can use
        /// it for rebasing even if the bookmark moves between resolve and commit.
        old_target: ChangesetId,
    },
    Delete {
        old_target: Option<ChangesetId>,
    },
}

/// Resolved manifest bookmark modification ready for execution.
struct ResolvedManifestMod {
    repo_name: String,
    bookmark: BookmarkKey,
    manifest_content: Bytes,
}

impl MultiRepoLandServiceImpl {
    pub async fn multiple_repo_modify_bookmarks(
        &self,
        ctx: CoreContext,
        params: MultipleRepoModifyBookmarksParams,
    ) -> Result<MultipleRepoModifyBookmarksResponse> {
        let service_identity = params
            .service_identity
            .as_deref()
            .unwrap_or("multi_repo_land");

        // -- Phase 1: Resolve all parameters --

        let resolved_mods = self
            .resolve_bookmark_modifications(&ctx, &params.repo_bookmark_modifications)
            .await?;
        let resolved_manifest_mods =
            self.resolve_manifest_modifications(&params.manifest_bookmark_modifications)?;

        // -- Phase 2: Create manifest commits --
        //
        // Each manifest modification creates a new commit on top of the
        // current bookmark position. The bookmark will be moved to this
        // commit as part of the atomic transaction.

        let mut manifest_targets: Vec<(String, BookmarkKey, ChangesetId, ChangesetId)> = Vec::new();
        for m in &resolved_manifest_mods {
            let repo = self.get_repo(&m.repo_name)?;
            let bookmark_cs = repo
                .bookmarks()
                .get(ctx.clone(), &m.bookmark, Freshness::MostRecent)
                .await?
                .ok_or_else(|| anyhow!("manifest bookmark not found: {}", m.bookmark))?;

            let manifest_path = NonRootMPath::new("manifest.xml")?;
            let new_cs = create_manifest_commit(
                &ctx,
                &repo,
                bookmark_cs,
                &manifest_path,
                m.manifest_content.clone(),
                service_identity,
            )
            .await?;
            manifest_targets.push((m.repo_name.clone(), m.bookmark.clone(), new_cs, bookmark_cs));
        }

        // -- Phase 3: Run hooks --
        //
        // Service-authored pushes bypass most hooks, but we still run them
        // to allow logging hooks to fire.

        self.run_all_hooks(&ctx, &resolved_mods).await?;

        // -- Phase 4: Build and commit the multi-repo transaction --

        let any_repo = self.get_any_repo(&resolved_mods, &resolved_manifest_mods)?;
        let write_connection = any_repo.sql_bookmarks().write_connection().clone();
        let mut txn = MultiRepoBookmarksTransaction::new(ctx.clone(), write_connection);

        // Add regular bookmark modifications.
        for m in &resolved_mods {
            let repo = self.get_repo(&m.repo_name)?;
            let repo_id = repo.repo_identity().id();

            match &m.kind {
                ResolvedModKind::Move { target, old_target } => {
                    txn.update(
                        repo_id,
                        &m.bookmark,
                        *target,
                        *old_target,
                        BookmarkUpdateReason::ManualMove,
                    )?;
                }
                ResolvedModKind::Create { target } => {
                    txn.create(
                        repo_id,
                        &m.bookmark,
                        *target,
                        BookmarkUpdateReason::ManualMove,
                    )?;
                }
                ResolvedModKind::Delete { old_target } => {
                    let old = match old_target {
                        Some(cs) => *cs,
                        None => repo
                            .bookmarks()
                            .get(ctx.clone(), &m.bookmark, Freshness::MostRecent)
                            .await?
                            .ok_or_else(|| {
                                anyhow!("bookmark {} not found in {}", m.bookmark, m.repo_name)
                            })?,
                    };
                    txn.delete(repo_id, &m.bookmark, old, BookmarkUpdateReason::ManualMove)?;
                }
            }
        }

        // Add manifest bookmark updates.
        for (repo_name, bookmark, new_cs, old_cs) in &manifest_targets {
            let repo = self.get_repo(repo_name)?;
            let repo_id = repo.repo_identity().id();
            txn.update(
                repo_id,
                bookmark,
                *new_cs,
                *old_cs,
                BookmarkUpdateReason::ManualMove,
            )?;
        }

        let result = txn.commit().await?;
        if result.is_success() {
            let mut results: Vec<RepoBookmarkResult> = resolved_mods
                .iter()
                .map(|m| RepoBookmarkResult {
                    repo_name: m.repo_name.clone(),
                    bookmark_name: m.bookmark.to_string(),
                })
                .collect();
            for (repo_name, bookmark, _, _) in &manifest_targets {
                results.push(RepoBookmarkResult {
                    repo_name: repo_name.clone(),
                    bookmark_name: bookmark.to_string(),
                });
            }

            return Ok(MultipleRepoModifyBookmarksResponse { results });
        }

        // -- Phase 5: CAS failure — rebase and return --
        self.handle_cas_failure(&ctx, &resolved_mods).await
    }
}

// --- Helper methods on the service impl ---

impl MultiRepoLandServiceImpl {
    fn get_repo(&self, name: &str) -> Result<Arc<Repo>> {
        self.repos_mgr
            .repos()
            .get_by_name(name)
            .ok_or_else(|| anyhow!("repo not found: {}", name))
    }

    /// Pick any repo to get the shared write connection from.
    fn get_any_repo(
        &self,
        mods: &[ResolvedBookmarkMod],
        manifest_mods: &[ResolvedManifestMod],
    ) -> Result<Arc<Repo>> {
        let name = mods
            .first()
            .map(|m| m.repo_name.as_str())
            .or_else(|| manifest_mods.first().map(|m| m.repo_name.as_str()))
            .ok_or_else(|| anyhow!("no bookmark modifications provided"))?;
        self.get_repo(name)
    }

    /// Resolve Thrift bookmark modifications into internal representations
    /// with all CommitIds converted to ChangesetIds.
    async fn resolve_bookmark_modifications(
        &self,
        ctx: &CoreContext,
        mods: &[RepoBookmarkModification],
    ) -> Result<Vec<ResolvedBookmarkMod>> {
        let mut resolved = Vec::with_capacity(mods.len());
        for m in mods {
            let repo_name = m.repo.name.clone();
            let repo = self.get_repo(&repo_name)?;
            let bookmark = BookmarkKey::new(&m.bookmark_name)?;
            let pushvars = m
                .pushvars
                .clone()
                .map(|pv| pv.into_iter().map(|(k, v)| (k, Bytes::from(v))).collect());

            let kind = match &m.modification {
                RepoBookmarkModificationSpec::move_bookmark(mv) => {
                    let target = resolve_commit_id(ctx, &repo, &mv.target).await?;
                    let old_target = match &mv.old_target {
                        Some(id) => resolve_commit_id(ctx, &repo, id).await?,
                        None => repo
                            .bookmarks()
                            .get(ctx.clone(), &bookmark, Freshness::MostRecent)
                            .await?
                            .ok_or_else(|| {
                                anyhow!("bookmark {} not found in {}", bookmark, repo_name)
                            })?,
                    };
                    ResolvedModKind::Move { target, old_target }
                }
                RepoBookmarkModificationSpec::create_bookmark(cr) => {
                    let target = resolve_commit_id(ctx, &repo, &cr.target).await?;
                    ResolvedModKind::Create { target }
                }
                RepoBookmarkModificationSpec::delete_bookmark(del) => {
                    let old_target = match &del.old_target {
                        Some(id) => Some(resolve_commit_id(ctx, &repo, id).await?),
                        None => None,
                    };
                    ResolvedModKind::Delete { old_target }
                }
                RepoBookmarkModificationSpec::UnknownField(v) => {
                    return Err(anyhow!("unknown bookmark modification variant: {}", v));
                }
            };

            resolved.push(ResolvedBookmarkMod {
                repo_name,
                bookmark,
                kind,
                pushvars,
            });
        }
        Ok(resolved)
    }

    fn resolve_manifest_modifications(
        &self,
        mods: &[ManifestBookmarkModification],
    ) -> Result<Vec<ResolvedManifestMod>> {
        mods.iter()
            .map(|m| {
                Ok(ResolvedManifestMod {
                    repo_name: m.repo.name.clone(),
                    bookmark: BookmarkKey::new(&m.bookmark_name)?,
                    manifest_content: Bytes::from(m.manifest_content.clone()),
                })
            })
            .collect()
    }

    /// Run bookmark and changeset hooks for all modifications.
    async fn run_all_hooks(&self, ctx: &CoreContext, mods: &[ResolvedBookmarkMod]) -> Result<()> {
        for m in mods {
            let repo = self.get_repo(&m.repo_name)?;
            let hook_manager = repo.hook_manager();

            // For move/create we have a target changeset to run hooks against.
            let target = match &m.kind {
                ResolvedModKind::Move { target, .. } => Some(*target),
                ResolvedModKind::Create { target } => Some(*target),
                ResolvedModKind::Delete { .. } => None,
            };

            if let Some(cs_id) = target {
                let bcs = cs_id
                    .load(ctx, repo.repo_blobstore())
                    .await
                    .map_err(|e| anyhow!("failed to load changeset {}: {}", cs_id, e))?;

                bookmarks_movement::run_bookmark_hooks(
                    ctx,
                    hook_manager,
                    &m.bookmark,
                    &bcs,
                    m.pushvars.as_ref(),
                    CrossRepoPushSource::NativeToThisRepo,
                    PushAuthoredBy::Service,
                )
                .await
                .map_err(|e| anyhow!("hook rejection in repo {}: {}", m.repo_name, e))?;
            }
        }
        Ok(())
    }

    /// After a CAS failure, read current bookmark positions, rebase all
    /// changesets onto the new positions, and return the appropriate error.
    async fn handle_cas_failure(
        &self,
        ctx: &CoreContext,
        mods: &[ResolvedBookmarkMod],
    ) -> Result<MultipleRepoModifyBookmarksResponse> {
        let mut rebased_entries = Vec::new();
        let mut conflict_entries = Vec::new();
        let mut aggregate_merge_info = MergeInfo::default();

        for m in mods {
            let (cs_id, old_target) = match &m.kind {
                ResolvedModKind::Move { target, old_target } => (*target, *old_target),
                _ => continue,
            };

            let repo = self.get_repo(&m.repo_name)?;
            let current_bookmark = repo
                .bookmarks()
                .get(ctx.clone(), &m.bookmark, Freshness::MostRecent)
                .await?;

            let Some(current_cs) = current_bookmark else {
                continue;
            };

            if old_target == current_cs {
                // Bookmark hasn't actually moved; no rebase needed.
                continue;
            }

            match rebase_changeset(ctx, &repo, cs_id, old_target, current_cs).await? {
                RebaseOutcome::Success(result) => {
                    aggregate_merge_info.aggregate(&result.merge_info);
                    rebased_entries.push(RebasedCommitEntry {
                        repo_name: m.repo_name.clone(),
                        bookmark_name: m.bookmark.to_string(),
                        original_commit: thrift::CommitId::bonsai(cs_id.as_ref().to_vec()),
                        rebased_commit: thrift::CommitId::bonsai(
                            result.rebased_cs_id.as_ref().to_vec(),
                        ),
                        new_bookmark_target: thrift::CommitId::bonsai(current_cs.as_ref().to_vec()),
                    });
                }
                RebaseOutcome::Conflict {
                    description,
                    merge_info,
                } => {
                    aggregate_merge_info.aggregate(&merge_info);
                    conflict_entries.push(RebaseConflictEntry {
                        repo_name: m.repo_name.clone(),
                        bookmark_name: m.bookmark.to_string(),
                        original_commit: thrift::CommitId::bonsai(cs_id.as_ref().to_vec()),
                        current_bookmark_target: thrift::CommitId::bonsai(
                            current_cs.as_ref().to_vec(),
                        ),
                        conflict_description: description,
                    });
                }
            }
        }

        if !conflict_entries.is_empty() {
            return Err(RebaseConflictWithMergeInfo {
                rebase_conflict: MultiRepoLandRebaseConflict {
                    message: format!(
                        "{} bookmark(s) have rebase conflicts",
                        conflict_entries.len()
                    ),
                    conflicts: conflict_entries,
                },
                merge_info: aggregate_merge_info,
            }
            .into());
        }

        Err(CasFailureWithMergeInfo {
            cas_failure: MultiRepoLandCasFailure {
                message: "CAS failure: bookmarks moved since read".to_string(),
                rebased_commits: rebased_entries,
            },
            merge_info: aggregate_merge_info,
        }
        .into())
    }
}

/// Resolve a Thrift CommitId to a Mononoke ChangesetId.
///
/// Supports bonsai (direct) and git (via bonsai_git_mapping) schemes.
async fn resolve_commit_id(
    ctx: &CoreContext,
    repo: &Repo,
    commit_id: &thrift::CommitId,
) -> Result<ChangesetId> {
    match commit_id {
        thrift::CommitId::bonsai(bytes) => {
            ChangesetId::from_bytes(bytes).map_err(|e| anyhow!("invalid bonsai commit id: {}", e))
        }
        thrift::CommitId::git(bytes) => {
            let git_sha1 = mononoke_types::hash::GitSha1::from_bytes(bytes)
                .map_err(|e| anyhow!("invalid git sha1: {}", e))?;
            repo.bonsai_git_mapping()
                .get_bonsai_from_git_sha1(ctx, git_sha1)
                .await?
                .ok_or_else(|| anyhow!("git commit not found: {}", git_sha1))
        }
        other => Err(anyhow!(
            "unsupported commit id scheme for multi-repo land: {:?}",
            other
        )),
    }
}
