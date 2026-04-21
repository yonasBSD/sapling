/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! Virtual manifest type that pairs an `HgManifestId` with an optional
//! `AclManifestId` overlay. Implementing `Loadable` and `Manifest` lets
//! `derive_manifest_from_predecessor` thread ACL overlay information
//! through the tree naturally, without modifying the generic traversal.

use anyhow::Result;
use async_trait::async_trait;
use blobstore::KeyedBlobstore;
use blobstore::LoadableError;
use context::CoreContext;
use futures::future;
use futures::stream::BoxStream;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;
use manifest::Entry;
use manifest::Manifest;
use mercurial_types::FileType;
use mercurial_types::HgFileNodeId;
use mercurial_types::HgManifestId;
use mercurial_types::blobs::HgBlobManifest;
use mononoke_types::MPathElement;
use mononoke_types::acl_manifest::AclManifest;
use mononoke_types::acl_manifest::AclManifestEntry;
use mononoke_types::typed_hash::AclManifestId;

/// Virtual manifest ID wrapping `(HgManifestId, Option<AclManifestId>)`.
/// Used as the predecessor for `derive_manifest_from_predecessor` so that
/// ACL overlay information propagates naturally during full/backfill derivation.
#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub struct AclOverlayHgManifestId {
    pub hg_manifest_id: HgManifestId,
    pub acl_manifest_id: Option<AclManifestId>,
}

/// Loaded manifest that carries the HgBlobManifest together with the
/// corresponding AclManifest node (if this directory is in the sparse ACL tree).
/// Child ACL IDs are resolved lazily via `AclManifest::lookup` during
/// `list()` and `lookup()`, avoiding pre-computation of the full child map.
pub struct AclOverlayHgManifest {
    hg_manifest: HgBlobManifest,
    acl_manifest: Option<AclManifest>,
}

#[async_trait]
impl blobstore::Loadable for AclOverlayHgManifestId {
    type Value = AclOverlayHgManifest;

    async fn load<'a, B: KeyedBlobstore>(
        &'a self,
        ctx: &'a CoreContext,
        blobstore: &'a B,
    ) -> Result<Self::Value, LoadableError> {
        let (hg_manifest, acl_manifest) = match &self.acl_manifest_id {
            Some(acl_id) => {
                let (hg, acl) = future::try_join(
                    blobstore::Loadable::load(&self.hg_manifest_id, ctx, blobstore),
                    blobstore::Loadable::load(acl_id, ctx, blobstore),
                )
                .await?;
                (hg, Some(acl))
            }
            None => {
                let hg = blobstore::Loadable::load(&self.hg_manifest_id, ctx, blobstore).await?;
                (hg, None)
            }
        };
        Ok(AclOverlayHgManifest {
            hg_manifest,
            acl_manifest,
        })
    }
}

/// Look up a child directory's ACL ID from the ACL manifest overlay.
/// Returns `Some(id)` if the child is a directory in the sparse ACL tree,
/// `None` otherwise (child not in ACL tree, is a .slacl leaf, or no overlay).
async fn resolve_child_acl_id<B: KeyedBlobstore>(
    acl_manifest: &Option<AclManifest>,
    ctx: &CoreContext,
    blobstore: &B,
    name: &MPathElement,
) -> Result<Option<AclManifestId>> {
    match acl_manifest {
        Some(acl) => match acl.lookup(ctx, blobstore, name).await? {
            Some(AclManifestEntry::Directory(dir)) => Ok(Some(dir.id)),
            _ => Ok(None),
        },
        None => Ok(None),
    }
}

#[async_trait]
impl<Store: KeyedBlobstore> Manifest<Store> for AclOverlayHgManifest {
    type TreeId = AclOverlayHgManifestId;
    type Leaf = (FileType, HgFileNodeId);
    type TrieMapType = ();

    async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
        name: &MPathElement,
    ) -> Result<Option<Entry<Self::TreeId, Self::Leaf>>> {
        let hg_entry = self.hg_manifest.lookup(ctx, blobstore, name).await?;
        match hg_entry {
            Some(Entry::Tree(hg_id)) => {
                let acl_id = resolve_child_acl_id(&self.acl_manifest, ctx, blobstore, name).await?;
                Ok(Some(Entry::Tree(AclOverlayHgManifestId {
                    hg_manifest_id: hg_id,
                    acl_manifest_id: acl_id,
                })))
            }
            Some(Entry::Leaf(leaf)) => Ok(Some(Entry::Leaf(leaf))),
            None => Ok(None),
        }
    }

    async fn list(
        &self,
        ctx: &CoreContext,
        blobstore: &Store,
    ) -> Result<BoxStream<'async_trait, Result<(MPathElement, Entry<Self::TreeId, Self::Leaf>)>>>
    {
        let acl_manifest = self.acl_manifest.clone();
        let inner_stream = self.hg_manifest.list(ctx, blobstore).await?;
        Ok(inner_stream
            .and_then(move |(name, entry)| {
                let acl_manifest = acl_manifest.clone();
                async move {
                    let mapped = match entry {
                        Entry::Tree(hg_id) => {
                            let acl_id =
                                resolve_child_acl_id(&acl_manifest, ctx, blobstore, &name).await?;
                            Entry::Tree(AclOverlayHgManifestId {
                                hg_manifest_id: hg_id,
                                acl_manifest_id: acl_id,
                            })
                        }
                        Entry::Leaf(leaf) => Entry::Leaf(leaf),
                    };
                    Ok((name, mapped))
                }
            })
            .boxed())
    }

    async fn into_trie_map(
        self,
        _ctx: &CoreContext,
        _blobstore: &Store,
    ) -> Result<Self::TrieMapType> {
        anyhow::bail!("into_trie_map is not supported for AclOverlayHgManifest")
    }
}
