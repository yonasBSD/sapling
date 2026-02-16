/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashSet;

use anyhow::Result;
use blobstore::Loadable;
use changesets_creation::save_changesets;
use commit_graph::CommitGraphRef;
use context::CoreContext;
use futures::StreamExt;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::MPath;
use mononoke_types::find_path_conflicts;
use repo_blobstore::RepoBlobstoreRef;

use crate::repo::Repo;

#[allow(dead_code)]
pub struct RebaseResult {
    pub rebased_cs_id: ChangesetId,
}

#[allow(dead_code)]
pub enum RebaseOutcome {
    Success(RebaseResult),
    /// The rebase could not complete because files in the changeset conflict
    /// with changes between old_parent and new_parent.
    Conflict(String),
}

/// Rebase a single changeset onto a new parent.
///
/// Performs a simple parent-swap: the changeset's file changes are preserved
/// but its parent is replaced. If any files changed by the changeset also
/// changed in old_parent..new_parent, returns `Conflict` instead.
#[allow(dead_code)]
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
    if !conflicts.is_empty() {
        let description = format!(
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
        );
        return Ok(RebaseOutcome::Conflict(description));
    }

    // Swap parent and create the rebased changeset.
    let mut bcs_mut = bcs.into_mut();
    bcs_mut.parents = vec![new_parent];

    let rebased = bcs_mut.freeze()?;
    let rebased_cs_id = rebased.get_changeset_id();
    save_changesets(ctx, repo, vec![rebased]).await?;

    Ok(RebaseOutcome::Success(RebaseResult { rebased_cs_id }))
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

        // Both touched "shared_file", so rebase should report a conflict.
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
}
