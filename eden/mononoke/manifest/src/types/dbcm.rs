/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use async_trait::async_trait;
use blobstore::KeyedBlobstore;
use context::CoreContext;
use futures::stream::BoxStream;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;
use mononoke_types::MPathElement;
use mononoke_types::directory_branch_cluster_manifest::DirectoryBranchClusterManifest;
use mononoke_types::directory_branch_cluster_manifest::DirectoryBranchClusterManifestEntry;
use mononoke_types::directory_branch_cluster_manifest::DirectoryBranchClusterManifestFile;
use mononoke_types::sharded_map_v2::LoadableShardedMapV2Node;

use super::Entry;
use super::Manifest;

/// Convert a DBCM entry to a manifest entry.
///
/// Files are leaves (containing cluster info) and directories are trees.
pub(crate) fn dbcm_to_mf_entry(
    entry: DirectoryBranchClusterManifestEntry,
) -> Entry<DirectoryBranchClusterManifest, DirectoryBranchClusterManifestFile> {
    match entry {
        DirectoryBranchClusterManifestEntry::File(file) => Entry::Leaf(file),
        DirectoryBranchClusterManifestEntry::Directory(dir) => Entry::Tree(dir),
    }
}

#[async_trait]
impl<Store: KeyedBlobstore> Manifest<Store> for DirectoryBranchClusterManifest {
    type TreeId = DirectoryBranchClusterManifest;
    /// DBCM file entries contain cluster membership info.
    type Leaf = DirectoryBranchClusterManifestFile;
    type TrieMapType = LoadableShardedMapV2Node<DirectoryBranchClusterManifestEntry>;

    async fn list(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
    ) -> Result<BoxStream<'async_trait, Result<(MPathElement, Entry<Self::TreeId, Self::Leaf>)>>>
    {
        anyhow::Ok(
            self.clone()
                .into_subentries(ctx, blobstore)
                .map_ok(|(path, entry)| (path, dbcm_to_mf_entry(entry)))
                .boxed(),
        )
    }

    async fn list_prefix(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
        prefix: &[u8],
    ) -> Result<BoxStream<'async_trait, Result<(MPathElement, Entry<Self::TreeId, Self::Leaf>)>>>
    {
        anyhow::Ok(
            self.clone()
                .into_prefix_subentries(ctx, blobstore, prefix)
                .map_ok(|(path, entry)| (path, dbcm_to_mf_entry(entry)))
                .boxed(),
        )
    }

    async fn list_skip(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
        skip: usize,
    ) -> Result<BoxStream<'async_trait, Result<(MPathElement, Entry<Self::TreeId, Self::Leaf>)>>>
    {
        anyhow::Ok(
            self.clone()
                .into_subentries_skip(ctx, blobstore, skip)
                .map_ok(|(path, entry)| (path, dbcm_to_mf_entry(entry)))
                .boxed(),
        )
    }

    async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
        name: &MPathElement,
    ) -> Result<Option<Entry<Self::TreeId, Self::Leaf>>> {
        Ok(self
            .lookup(ctx, blobstore, name)
            .await?
            .map(dbcm_to_mf_entry))
    }

    async fn into_trie_map(
        self,
        _ctx: &CoreContext,
        _blobstore: &Store,
    ) -> Result<Self::TrieMapType> {
        Ok(LoadableShardedMapV2Node::Inlined(self.subentries))
    }
}
