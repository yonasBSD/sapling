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
use mononoke_types::sharded_map_v2::LoadableShardedMapV2Node;

use super::Entry;
use super::Manifest;

/// Convert a DBCM subdirectory to a manifest entry.
///
/// DBCM only stores directories (no files), so this always returns `Entry::Tree`.
pub(crate) fn dbcm_to_mf_entry(
    dir: DirectoryBranchClusterManifest,
) -> Entry<DirectoryBranchClusterManifest, ()> {
    Entry::Tree(dir)
}

#[async_trait]
impl<Store: KeyedBlobstore> Manifest<Store> for DirectoryBranchClusterManifest {
    type TreeId = DirectoryBranchClusterManifest;
    /// DBCM has no leaves (files) - it only tracks directories.
    /// The Leaf type is `()` but no Leaf entries are ever returned.
    type Leaf = ();
    type TrieMapType = LoadableShardedMapV2Node<DirectoryBranchClusterManifest>;

    async fn list(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
    ) -> Result<BoxStream<'async_trait, Result<(MPathElement, Entry<Self::TreeId, Self::Leaf>)>>>
    {
        anyhow::Ok(
            self.clone()
                .into_subentries(ctx, blobstore)
                .map_ok(|(path, dir)| (path, dbcm_to_mf_entry(dir)))
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
                .map_ok(|(path, dir)| (path, dbcm_to_mf_entry(dir)))
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
                .map_ok(|(path, dir)| (path, dbcm_to_mf_entry(dir)))
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
