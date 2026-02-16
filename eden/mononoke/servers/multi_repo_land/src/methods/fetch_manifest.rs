/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use anyhow::anyhow;
use bookmarks::BookmarkKey;
use bookmarks::BookmarksRef;
use bookmarks::Freshness;
use context::CoreContext;
use derivation_queue_thrift::DerivationPriority;
use fsnodes::RootFsnodeId;
use manifest::Entry;
use manifest::ManifestOps;
use mononoke_types::NonRootMPath;
use multi_repo_land_if::RepoFetchManifestContentParams;
use multi_repo_land_if::RepoFetchManifestContentResponse;
use repo_blobstore::RepoBlobstoreRef;
use repo_derived_data::RepoDerivedDataRef;

use crate::service::MultiRepoLandServiceImpl;

impl MultiRepoLandServiceImpl {
    pub async fn repo_fetch_manifest_content(
        &self,
        ctx: CoreContext,
        params: RepoFetchManifestContentParams,
    ) -> Result<RepoFetchManifestContentResponse> {
        let repo_name = &params.repo.name;
        let repo = self
            .repos_mgr
            .repos()
            .get_by_name(repo_name)
            .ok_or_else(|| anyhow!("repo not found: {}", repo_name))?;

        let bookmark = BookmarkKey::new(&params.bookmark)?;
        let cs_id = repo
            .bookmarks()
            .get(ctx.clone(), &bookmark, Freshness::MostRecent)
            .await?
            .ok_or_else(|| anyhow!("bookmark not found: {}", params.bookmark))?;

        let root_fsnode_id = repo
            .repo_derived_data()
            .derive::<RootFsnodeId>(&ctx, cs_id, DerivationPriority::LOW)
            .await?;

        let path = NonRootMPath::new(&params.path)?;
        let entry = root_fsnode_id
            .fsnode_id()
            .find_entry(ctx.clone(), repo.repo_blobstore().clone(), path.into())
            .await?
            .ok_or_else(|| anyhow!("path not found: {}", params.path))?;

        let content_id = match entry {
            Entry::Leaf(fsnode_file) => *fsnode_file.content_id(),
            Entry::Tree(_) => {
                return Err(anyhow!("path is a directory, not a file: {}", params.path));
            }
        };

        let content = filestore::fetch_concat(repo.repo_blobstore(), &ctx, content_id).await?;

        Ok(RepoFetchManifestContentResponse {
            manifest_content: content.to_vec(),
        })
    }
}
