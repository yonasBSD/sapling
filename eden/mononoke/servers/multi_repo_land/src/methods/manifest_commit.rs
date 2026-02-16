/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use bytes::Bytes;
use changesets_creation::save_changesets;
use context::CoreContext;
use filestore::FilestoreConfigRef;
use filestore::StoreRequest;
use futures::stream;
use mononoke_types::BonsaiChangesetMut;
use mononoke_types::ChangesetId;
use mononoke_types::DateTime;
use mononoke_types::FileChange;
use mononoke_types::FileType;
use mononoke_types::GitLfs;
use mononoke_types::NonRootMPath;
use repo_blobstore::RepoBlobstoreRef;
use sorted_vector_map::sorted_vector_map;

use crate::repo::Repo;

/// Create a commit that updates the manifest file on top of a parent changeset.
///
/// The commit is stored in the blobstore but no bookmark points to it yet.
/// The caller is responsible for moving the bookmark as part of the atomic
/// multi-repo transaction.
pub async fn create_manifest_commit(
    ctx: &CoreContext,
    repo: &Repo,
    parent: ChangesetId,
    manifest_path: &NonRootMPath,
    manifest_content: Bytes,
    service_identity: &str,
) -> Result<ChangesetId> {
    let size = manifest_content.len() as u64;

    let metadata = filestore::store(
        repo.repo_blobstore(),
        *repo.filestore_config(),
        ctx,
        &StoreRequest::new(size),
        stream::once(async { Ok(manifest_content) }),
    )
    .await?;

    let file_changes = sorted_vector_map! {
        manifest_path.clone() => FileChange::tracked(
            metadata.content_id,
            FileType::Regular,
            metadata.total_size,
            None,
            GitLfs::FullContent,
        ),
    };

    let bcs_mut = BonsaiChangesetMut {
        parents: vec![parent],
        author: service_identity.to_string(),
        author_date: DateTime::now(),
        committer: None,
        committer_date: None,
        message: format!("Update static manifest at {}", manifest_path),
        hg_extra: Default::default(),
        git_extra_headers: None,
        file_changes,
        is_snapshot: false,
        git_tree_hash: None,
        git_annotated_tag: None,
        subtree_changes: Default::default(),
    };

    let bcs = bcs_mut.freeze()?;
    let cs_id = bcs.get_changeset_id();
    save_changesets(ctx, repo, vec![bcs]).await?;

    Ok(cs_id)
}

#[cfg(test)]
mod tests {
    use anyhow::Result;
    use blobstore::Loadable;
    use context::CoreContext;
    use fbinit::FacebookInit;
    use mononoke_macros::mononoke;
    use mononoke_types::NonRootMPath;
    use repo_blobstore::RepoBlobstoreRef;
    use tests_utils::CreateCommitContext;

    use super::*;
    use crate::repo::Repo;

    #[mononoke::fbinit_test]
    async fn test_creates_commit_on_top_of_parent(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let parent = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("existing", "data")
            .commit()
            .await?;

        let manifest_path = NonRootMPath::new("manifest.xml")?;
        let cs_id = create_manifest_commit(
            &ctx,
            &repo,
            parent,
            &manifest_path,
            Bytes::from("<manifest/>"),
            "test_service",
        )
        .await?;

        // The new commit should have the parent as its only parent.
        let bcs = cs_id.load(&ctx, repo.repo_blobstore()).await?;
        assert_eq!(bcs.parents().collect::<Vec<_>>(), vec![parent]);
        assert_ne!(cs_id, parent);
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_commit_has_correct_file_change(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let parent = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("readme", "hello")
            .commit()
            .await?;

        let manifest_path = NonRootMPath::new("path/to/manifest.xml")?;
        let content = b"<manifest><project/></manifest>";
        let cs_id = create_manifest_commit(
            &ctx,
            &repo,
            parent,
            &manifest_path,
            Bytes::from(content.as_slice()),
            "test_service",
        )
        .await?;

        let bcs = cs_id.load(&ctx, repo.repo_blobstore()).await?;

        // Verify the manifest file is the only change.
        let changed_paths: Vec<_> = bcs.file_changes().map(|(p, _)| p.clone()).collect();
        assert_eq!(changed_paths, vec![manifest_path]);

        // Verify author and message.
        assert_eq!(bcs.author(), "test_service");
        assert!(bcs.message().contains("manifest.xml"));

        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_commit_stores_correct_content(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: Repo = test_repo_factory::build_empty(fb).await?;

        let parent = CreateCommitContext::new_root(&ctx, &repo)
            .add_file("readme", "hello")
            .commit()
            .await?;

        let manifest_path = NonRootMPath::new("manifest.xml")?;
        let content = Bytes::from("test content 12345");
        let cs_id =
            create_manifest_commit(&ctx, &repo, parent, &manifest_path, content.clone(), "svc")
                .await?;

        // Verify the stored file size matches.
        let bcs = cs_id.load(&ctx, repo.repo_blobstore()).await?;
        let (_, file_change) = bcs.file_changes().next().unwrap();
        let tracked = file_change.simplify().unwrap();
        assert_eq!(tracked.size(), content.len() as u64);

        Ok(())
    }
}
