/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashSet;

use anyhow::Result;
use blobstore::Loadable;
use bytes::Bytes;
use changesets_creation::save_changesets;
use commit_graph::CommitGraphRef;
use context::CoreContext;
use derivation_queue_thrift::DerivationPriority;
use filestore::FilestoreConfigRef;
use filestore::StoreRequest;
use fsnodes::RootFsnodeId;
use futures::StreamExt;
use futures::stream;
use manifest::Entry;
use manifest::ManifestOps;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::FileChange;
use mononoke_types::FileType;
use mononoke_types::GitLfs;
use mononoke_types::MPath;
use mononoke_types::NonRootMPath;
use mononoke_types::find_path_conflicts;
use repo_blobstore::RepoBlobstoreRef;
use repo_derived_data::RepoDerivedDataRef;
use repo_identity::RepoIdentityRef;
use three_way_merge::MergeResult;

use crate::repo::Repo;

pub struct RebaseResult {
    pub rebased_cs_id: ChangesetId,
}

pub enum RebaseOutcome {
    Success(RebaseResult),
    /// The rebase could not complete because files in the changeset conflict
    /// with changes between old_parent and new_parent.
    Conflict(String),
}

/// Rebase a single changeset onto a new parent.
///
/// Performs a parent-swap: the changeset's file changes are preserved but its
/// parent is replaced. If files changed by the changeset also changed in
/// old_parent..new_parent, attempts a 3-way content merge (when enabled via
/// JustKnob). Returns `Conflict` if any file can't be cleanly merged.
pub async fn rebase_changeset(
    ctx: &CoreContext,
    repo: &Repo,
    cs_id: ChangesetId,
    old_parent: ChangesetId,
    new_parent: ChangesetId,
) -> Result<RebaseOutcome> {
    if old_parent == new_parent {
        return Ok(RebaseOutcome::Success(RebaseResult {
            rebased_cs_id: cs_id,
        }));
    }

    let blobstore = repo.repo_blobstore();
    let bcs = cs_id.load(ctx, blobstore).await?;

    // Collect file paths changed by the changeset being rebased.
    let changeset_files: Vec<MPath> = changed_file_paths(&bcs).into_iter().collect();

    // Collect file paths changed between old_parent and new_parent.
    // Both are expected to be on the same branch, so walk the range.
    let server_files: Vec<MPath> = changed_files_in_range(ctx, repo, old_parent, new_parent)
        .await?
        .into_iter()
        .collect();

    // Detect path-level conflicts: any overlapping paths or prefix relationships.
    let conflicts = find_path_conflicts(changeset_files, server_files);

    let merged_changes = if !conflicts.is_empty() {
        match try_resolve_conflicts(ctx, repo, &bcs, old_parent, new_parent, conflicts).await? {
            Ok(changes) => changes,
            Err(description) => return Ok(RebaseOutcome::Conflict(description)),
        }
    } else {
        Vec::new()
    };

    // Swap parent and create the rebased changeset.
    let mut bcs_mut = bcs.into_mut();
    bcs_mut.parents = vec![new_parent];
    for (path, change) in merged_changes {
        bcs_mut.file_changes.insert(path, change);
    }

    let rebased = bcs_mut.freeze()?;
    let rebased_cs_id = rebased.get_changeset_id();
    save_changesets(ctx, repo, vec![rebased]).await?;

    Ok(RebaseOutcome::Success(RebaseResult { rebased_cs_id }))
}

/// Try to resolve path conflicts via 3-way content merge.
///
/// Returns `Ok(merged_changes)` if all conflicting files can be cleanly merged,
/// or `Err(description)` if any conflict is unresolvable.
async fn try_resolve_conflicts(
    ctx: &CoreContext,
    repo: &Repo,
    bcs: &BonsaiChangeset,
    old_parent: ChangesetId,
    new_parent: ChangesetId,
    conflicts: Vec<(MPath, MPath)>,
) -> Result<std::result::Result<Vec<(NonRootMPath, FileChange)>, String>> {
    // Prefix conflicts (file vs directory) can never be content-merged.
    let has_prefix_conflict = conflicts.iter().any(|(l, r)| l != r);
    if has_prefix_conflict {
        return Ok(Err(format_conflict_description(&conflicts)));
    }

    // All conflicts are exact-path (same file modified on both sides).
    // Check if 3-way content merge is enabled.
    let merge_enabled = justknobs::eval(
        "scm/mononoke:enable_three_way_merge_on_rebase",
        None,
        Some(repo.repo_identity().name()),
    )?;

    if !merge_enabled {
        return Ok(Err(format_conflict_description(&conflicts)));
    }

    // Attempt 3-way merge for each conflicting file.
    let mut merged_changes = Vec::new();

    for (conflict_path, _) in &conflicts {
        let non_root_path = match conflict_path.clone().into_optional_non_root_path() {
            Some(p) => p,
            None => {
                return Ok(Err("conflict at repository root (cannot merge)".to_string()));
            }
        };

        // Get the local file change from the changeset.
        let local_tracked = match bcs.file_changes_map().get(&non_root_path) {
            Some(FileChange::Change(tracked)) => tracked,
            _ => {
                // Deletion or untracked change — can't content-merge.
                return Ok(Err(format!(
                    "cannot content-merge {}: file was deleted or has untracked changes",
                    non_root_path
                )));
            }
        };

        // Load base content (at old_parent). If the file doesn't exist at old_parent
        // (both sides added it), use empty bytes.
        let base_bytes = match load_file_at_commit(ctx, repo, old_parent, conflict_path).await? {
            Some((bytes, _)) => bytes,
            None => Bytes::new(),
        };

        // Load local content from the changeset.
        let local_bytes =
            filestore::fetch_concat(repo.repo_blobstore(), ctx, local_tracked.content_id()).await?;

        // Load other content (at new_parent). If the file was deleted on the
        // server side, that's a modify/delete conflict.
        let other_bytes = match load_file_at_commit(ctx, repo, new_parent, conflict_path).await? {
            Some((bytes, _)) => bytes,
            None => {
                return Ok(Err(format!(
                    "cannot content-merge {}: file was deleted on the server side",
                    non_root_path
                )));
            }
        };

        // Attempt 3-way merge.
        match three_way_merge::merge_text(&base_bytes, &local_bytes, &other_bytes) {
            MergeResult::Clean(merged) => {
                let merged_bytes = Bytes::from(merged);
                let size = merged_bytes.len() as u64;

                let metadata = filestore::store(
                    repo.repo_blobstore(),
                    *repo.filestore_config(),
                    ctx,
                    &StoreRequest::new(size),
                    stream::once(async { Ok(merged_bytes) }),
                )
                .await?;

                let merged_change = FileChange::tracked(
                    metadata.content_id,
                    local_tracked.file_type(),
                    metadata.total_size,
                    local_tracked.copy_from().cloned(),
                    GitLfs::FullContent,
                );

                merged_changes.push((non_root_path, merged_change));
            }
            MergeResult::Conflict(desc) => {
                return Ok(Err(format!(
                    "content merge failed for {}: {}",
                    non_root_path, desc
                )));
            }
        }
    }

    Ok(Ok(merged_changes))
}

/// Load file content and type at a specific changeset via fsnode derivation.
///
/// Returns `None` if the file doesn't exist at that changeset.
async fn load_file_at_commit(
    ctx: &CoreContext,
    repo: &Repo,
    cs_id: ChangesetId,
    path: &MPath,
) -> Result<Option<(Bytes, FileType)>> {
    let root_fsnode = repo
        .repo_derived_data()
        .derive::<RootFsnodeId>(ctx, cs_id, DerivationPriority::LOW)
        .await?;

    match root_fsnode
        .fsnode_id()
        .find_entry(ctx.clone(), repo.repo_blobstore().clone(), path.clone())
        .await?
    {
        Some(Entry::Leaf(fsnode_file)) => {
            let content =
                filestore::fetch_concat(repo.repo_blobstore(), ctx, *fsnode_file.content_id())
                    .await?;
            Ok(Some((content, *fsnode_file.file_type())))
        }
        _ => Ok(None),
    }
}

/// Format a human-readable conflict description from a list of path conflicts.
fn format_conflict_description(conflicts: &[(MPath, MPath)]) -> String {
    format!(
        "conflicting paths: {}",
        conflicts
            .iter()
            .map(|(l, r)| if l == r {
                l.to_string()
            } else {
                format!("{} (conflicts with {})", l, r)
            })
            .collect::<Vec<_>>()
            .join(", ")
    )
}

/// Extract file paths changed by a single changeset, including copy sources.
fn changed_file_paths(bcs: &BonsaiChangeset) -> HashSet<MPath> {
    bcs.file_changes()
        .flat_map(|(path, file_change)| {
            let mut paths = vec![MPath::from(path.clone())];
            if let Some((copy_from, _)) = file_change.copy_from() {
                paths.push(MPath::from(copy_from.clone()));
            }
            paths
        })
        .collect()
}

/// Compute the union of changed file paths across all changesets in
/// ancestor..descendant (exclusive of ancestor).
async fn changed_files_in_range(
    ctx: &CoreContext,
    repo: &Repo,
    ancestor: ChangesetId,
    descendant: ChangesetId,
) -> Result<HashSet<MPath>> {
    let blobstore = repo.repo_blobstore();
    let cs_ids: Vec<ChangesetId> = repo
        .commit_graph()
        .range_stream(ctx, ancestor, descendant)
        .await?
        .collect()
        .await;

    let mut all_paths = HashSet::new();
    for id in cs_ids {
        if id == ancestor {
            continue;
        }
        let bcs = id.load(ctx, blobstore).await?;
        all_paths.extend(changed_file_paths(&bcs));
    }
    Ok(all_paths)
}

#[cfg(test)]
mod tests {
    use anyhow::Result;
    use blobstore::Loadable;
    use context::CoreContext;
    use fbinit::FacebookInit;
    use mononoke_macros::mononoke;
    use repo_blobstore::RepoBlobstoreRef;
    use tests_utils::CreateCommitContext;

    use super::*;
    use crate::repo::Repo;

    // -- rebase_changeset tests --

    #[mononoke::fbinit_test]
    async fn test_rebase_same_parent_returns_original(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("file", "content")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, root, root, root).await? {
            RebaseOutcome::Success(result) => {
                assert_eq!(result.rebased_cs_id, root);
            }
            RebaseOutcome::Conflict(_) => panic!("expected success, got conflict"),
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rebase_no_conflict(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        // Build: root -> server_commit (modifies "server_file")
        //        root -> user_commit (modifies "user_file")
        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("base", "content")
            .commit()
            .await?;

        let server_commit = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("server_file", "server data")
            .commit()
            .await?;

        let user_commit = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("user_file", "user data")
            .commit()
            .await?;

        // Rebase user_commit from root onto server_commit. No overlap, so
        // should succeed and produce a new changeset.
        match rebase_changeset(&ctx, &repo, user_commit, root, server_commit).await? {
            RebaseOutcome::Success(result) => {
                assert_ne!(result.rebased_cs_id, user_commit);
                // Verify the rebased changeset has new_parent as its parent.
                let bcs = result
                    .rebased_cs_id
                    .load(&ctx, repo.repo_blobstore())
                    .await?;
                assert_eq!(bcs.parents().collect::<Vec<_>>(), vec![server_commit]);
            }
            RebaseOutcome::Conflict(desc) => panic!("expected success, got conflict: {desc}"),
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rebase_with_conflict(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared_file", "original")
            .commit()
            .await?;

        let server_commit = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared_file", "server version")
            .commit()
            .await?;

        let user_commit = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared_file", "user version")
            .commit()
            .await?;

        // Both touched "shared_file", so rebase should report a conflict
        // (knob is off by default).
        match rebase_changeset(&ctx, &repo, user_commit, root, server_commit).await? {
            RebaseOutcome::Success(_) => panic!("expected conflict, got success"),
            RebaseOutcome::Conflict(desc) => {
                assert!(
                    desc.contains("shared_file"),
                    "conflict description should mention the conflicting file"
                );
            }
        }
        Ok(())
    }

    // -- 3-way content merge tests --
    // These tests use justknobs::override_just_knobs to enable the merge knob.

    fn enable_merge_knob() {
        justknobs::test_helpers::override_just_knobs(
            justknobs::test_helpers::JustKnobsInMemory::new(
                [(
                    "scm/mononoke:enable_three_way_merge_on_rebase".to_string(),
                    justknobs::test_helpers::KnobVal::Bool(true),
                )]
                .into(),
            ),
        );
    }

    /// Helper to fetch file content at a path from a changeset.
    async fn read_file(
        ctx: &CoreContext,
        repo: &Repo,
        cs_id: ChangesetId,
        path: &str,
    ) -> Result<Bytes> {
        let mpath = MPath::new(path)?;
        load_file_at_commit(ctx, repo, cs_id, &mpath)
            .await?
            .map(|(bytes, _)| bytes)
            .ok_or_else(|| anyhow::anyhow!("file {} not found at changeset {}", path, cs_id))
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_non_overlapping_edits(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        // Base file has 5 lines.
        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "line1\nline2\nline3\nline4\nline5\n")
            .commit()
            .await?;

        // Server modifies line 5.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nline2\nline3\nline4\nserver5\n")
            .commit()
            .await?;

        // User modifies line 1.
        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "user1\nline2\nline3\nline4\nline5\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(result) => {
                let merged = read_file(&ctx, &repo, result.rebased_cs_id, "shared").await?;
                assert_eq!(merged.as_ref(), b"user1\nline2\nline3\nline4\nserver5\n");
            }
            RebaseOutcome::Conflict(desc) => {
                panic!("expected clean merge, got conflict: {desc}")
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_true_conflict(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "line1\nline2\nline3\n")
            .commit()
            .await?;

        // Both sides modify line 2 differently.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nserver2\nline3\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nuser2\nline3\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => panic!("expected conflict, got success"),
            RebaseOutcome::Conflict(desc) => {
                assert!(
                    desc.contains("content merge failed"),
                    "should indicate content merge failure: {desc}"
                );
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_binary_conflict(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "binary\0base")
            .commit()
            .await?;

        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "binary\0server")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "binary\0user")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => panic!("expected conflict for binary file"),
            RebaseOutcome::Conflict(desc) => {
                assert!(desc.contains("binary"), "should mention binary: {desc}");
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_knob_disabled_returns_conflict(fb: FacebookInit) -> Result<()> {
        // Do NOT enable the merge knob — default is off.
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "line1\nline2\nline3\nline4\nline5\n")
            .commit()
            .await?;

        // Non-overlapping edits that WOULD merge cleanly if knob were on.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nline2\nline3\nline4\nserver5\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "user1\nline2\nline3\nline4\nline5\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => {
                panic!("expected conflict when knob is off, got success")
            }
            RebaseOutcome::Conflict(desc) => {
                assert!(desc.contains("shared"), "should mention the file: {desc}");
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_both_add_same_new_file(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("existing", "data")
            .commit()
            .await?;

        // Both sides add the same new file with identical content.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("new_file", "same content\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("new_file", "same content\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(result) => {
                let content = read_file(&ctx, &repo, result.rebased_cs_id, "new_file").await?;
                assert_eq!(content.as_ref(), b"same content\n");
            }
            RebaseOutcome::Conflict(desc) => {
                panic!("expected success for identical add/add, got conflict: {desc}")
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_both_add_different_new_file(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("existing", "data")
            .commit()
            .await?;

        // Both sides add a new file with different content.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("new_file", "server content\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("new_file", "user content\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => panic!("expected conflict for different add/add"),
            RebaseOutcome::Conflict(_) => {}
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_delete_vs_modify(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "original content\n")
            .commit()
            .await?;

        // Server deletes the file.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .delete_file("shared")
            .commit()
            .await?;

        // User modifies it.
        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "user modified\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => panic!("expected conflict for delete vs modify"),
            RebaseOutcome::Conflict(desc) => {
                assert!(desc.contains("deleted"), "should mention deletion: {desc}");
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_multiple_files_mixed(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("mergeable", "line1\nline2\nline3\nline4\nline5\n")
            .add_file("conflicting", "line1\nline2\nline3\n")
            .commit()
            .await?;

        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("mergeable", "line1\nline2\nline3\nline4\nserver5\n")
            .add_file("conflicting", "line1\nserver2\nline3\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("mergeable", "user1\nline2\nline3\nline4\nline5\n")
            .add_file("conflicting", "line1\nuser2\nline3\n")
            .commit()
            .await?;

        // One file merges cleanly, one conflicts. All-or-nothing: entire rebase fails.
        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(_) => {
                panic!("expected conflict when one file can't merge")
            }
            RebaseOutcome::Conflict(desc) => {
                assert!(
                    desc.contains("conflicting"),
                    "should mention the conflicting file: {desc}"
                );
            }
        }
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_content_merge_both_changed_identically(fb: FacebookInit) -> Result<()> {
        enable_merge_knob();
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let root = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("shared", "line1\nline2\nline3\n")
            .commit()
            .await?;

        // Both sides make the exact same change.
        let server = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nmodified\nline3\n")
            .commit()
            .await?;

        let user = CreateCommitContext::new(&ctx, &repo, vec![root])
            .add_file("shared", "line1\nmodified\nline3\n")
            .commit()
            .await?;

        match rebase_changeset(&ctx, &repo, user, root, server).await? {
            RebaseOutcome::Success(result) => {
                let content = read_file(&ctx, &repo, result.rebased_cs_id, "shared").await?;
                assert_eq!(content.as_ref(), b"line1\nmodified\nline3\n");
            }
            RebaseOutcome::Conflict(desc) => {
                panic!("expected success for identical edits, got conflict: {desc}")
            }
        }
        Ok(())
    }
}
