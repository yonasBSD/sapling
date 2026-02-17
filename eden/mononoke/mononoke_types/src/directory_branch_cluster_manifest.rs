/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use async_trait::async_trait;
use blobstore::KeyedBlobstore;
use blobstore::Loadable;
use blobstore::LoadableError;
use context::CoreContext;
use futures::stream::BoxStream;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;

use crate::Blob;
use crate::BlobstoreValue;
use crate::MPath;
use crate::MPathElement;
use crate::ThriftConvert;
use crate::blob::DirectoryBranchClusterManifestBlob;
use crate::sharded_map_v2::ShardedMapV2Node;
use crate::sharded_map_v2::ShardedMapV2Value;
use crate::thrift;
use crate::typed_hash::DirectoryBranchClusterManifestContext;
use crate::typed_hash::DirectoryBranchClusterManifestId;
use crate::typed_hash::IdContext;
use crate::typed_hash::ShardedMapV2NodeDbcmContext;
pub use crate::typed_hash::ShardedMapV2NodeDbcmId;

/// Trait for types that can be members of a cluster (have primary/secondaries fields).
/// This allows common operations on cluster membership to be shared between
/// DirectoryBranchClusterManifest and DirectoryBranchClusterManifestFile.
pub trait ClusterMember {
    /// Returns a reference to the primary path (path this entry was copied FROM), if any
    fn primary(&self) -> Option<&MPath>;

    /// Returns a mutable reference to the primary field
    fn primary_mut(&mut self) -> &mut Option<MPath>;

    /// Returns a reference to the secondaries (paths copied FROM this entry), if any
    fn secondaries(&self) -> Option<&[MPath]>;

    /// Returns a mutable reference to the secondaries field
    fn secondaries_mut(&mut self) -> &mut Option<Vec<MPath>>;

    /// Returns true if this entry is part of a cluster (is a primary or secondary)
    fn is_clustered(&self) -> bool {
        self.secondaries().is_some_and(|m| !m.is_empty()) || self.primary().is_some()
    }
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::directory_branch_cluster_manifest::DirectoryBranchClusterManifestEntry)]
pub enum DirectoryBranchClusterManifestEntry {
    File(DirectoryBranchClusterManifestFile),
    Directory(DirectoryBranchClusterManifest),
}

/// A file entry in the directory branch cluster manifest.
/// Files are leaf nodes and have no subentries, only cluster membership info.
#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::directory_branch_cluster_manifest::DirectoryBranchClusterManifestFile)]
pub struct DirectoryBranchClusterManifestFile {
    /// If this file is a cluster primary, lists its secondaries (paths copied FROM this file)
    pub secondaries: Option<Vec<MPath>>,
    /// If this file is a cluster secondary, the path it was copied FROM
    pub primary: Option<MPath>,
}

impl ClusterMember for DirectoryBranchClusterManifestFile {
    fn primary(&self) -> Option<&MPath> {
        self.primary.as_ref()
    }

    fn primary_mut(&mut self) -> &mut Option<MPath> {
        &mut self.primary
    }

    fn secondaries(&self) -> Option<&[MPath]> {
        self.secondaries.as_deref()
    }

    fn secondaries_mut(&mut self) -> &mut Option<Vec<MPath>> {
        &mut self.secondaries
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct DirectoryBranchClusterManifest {
    /// Subentries (subdirectories and files with cluster membership)
    pub subentries: ShardedMapV2Node<DirectoryBranchClusterManifestEntry>,
    /// If this entry is a cluster primary, lists its secondaries (paths copied FROM this entry)
    pub secondaries: Option<Vec<MPath>>,
    /// If this entry is a cluster secondary, the path it was copied FROM
    pub primary: Option<MPath>,
}

#[async_trait]
impl Loadable for DirectoryBranchClusterManifest {
    type Value = DirectoryBranchClusterManifest;

    async fn load<'a, B: KeyedBlobstore>(
        &'a self,
        _ctx: &'a CoreContext,
        _blobstore: &'a B,
    ) -> Result<Self::Value, LoadableError> {
        Ok(self.clone())
    }
}

impl ShardedMapV2Value for DirectoryBranchClusterManifestEntry {
    type NodeId = ShardedMapV2NodeDbcmId;
    type Context = ShardedMapV2NodeDbcmContext;
    type RollupData = ();

    const WEIGHT_LIMIT: usize = 1000;

    // The weight function is overridden because the sharded map is stored
    // inlined in DirectoryBranchClusterManifest. So the weight of the sharded map
    // should be propagated to make sure each sharded map blob stays
    // within the weight limit.
    fn weight(&self) -> usize {
        match self {
            Self::File(_) => 1,
            // This `1 +` is needed to offset the extra space required for
            // the bytes that represent the path element to this directory.
            Self::Directory(dir) => 1 + dir.subentries.weight(),
        }
    }
}

impl ThriftConvert for DirectoryBranchClusterManifest {
    const NAME: &'static str = "DirectoryBranchClusterManifest";
    type Thrift = thrift::directory_branch_cluster_manifest::DirectoryBranchClusterManifest;

    fn from_thrift(t: Self::Thrift) -> Result<Self> {
        let secondaries = t
            .secondaries
            .map(|members| {
                members
                    .into_iter()
                    .map(MPath::from_thrift)
                    .collect::<Result<Vec<_>>>()
            })
            .transpose()?;

        let primary = t.primary.map(MPath::from_thrift).transpose()?;

        Ok(Self {
            subentries: ShardedMapV2Node::from_thrift(t.subentries)?,
            secondaries,
            primary,
        })
    }

    fn into_thrift(self) -> Self::Thrift {
        let secondaries = self
            .secondaries
            .map(|members| members.into_iter().map(|m| m.into_thrift()).collect());

        let primary = self.primary.map(|m| m.into_thrift());

        thrift::directory_branch_cluster_manifest::DirectoryBranchClusterManifest {
            subentries: self.subentries.into_thrift(),
            secondaries,
            primary,
        }
    }
}

impl ClusterMember for DirectoryBranchClusterManifest {
    fn primary(&self) -> Option<&MPath> {
        self.primary.as_ref()
    }

    fn primary_mut(&mut self) -> &mut Option<MPath> {
        &mut self.primary
    }

    fn secondaries(&self) -> Option<&[MPath]> {
        self.secondaries.as_deref()
    }

    fn secondaries_mut(&mut self) -> &mut Option<Vec<MPath>> {
        &mut self.secondaries
    }
}

impl DirectoryBranchClusterManifest {
    pub fn empty() -> Self {
        Self {
            subentries: ShardedMapV2Node::default(),
            secondaries: None,
            primary: None,
        }
    }

    pub async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &impl KeyedBlobstore,
        name: &MPathElement,
    ) -> Result<Option<DirectoryBranchClusterManifestEntry>> {
        self.subentries.lookup(ctx, blobstore, name.as_ref()).await
    }

    pub fn into_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
    ) -> BoxStream<'a, Result<(MPathElement, DirectoryBranchClusterManifestEntry)>> {
        self.subentries
            .into_entries(ctx, blobstore)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }

    pub fn into_subentries_skip<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        skip: usize,
    ) -> BoxStream<'a, Result<(MPathElement, DirectoryBranchClusterManifestEntry)>> {
        self.subentries
            .into_entries_skip(ctx, blobstore, skip)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }

    pub fn into_prefix_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        prefix: &'a [u8],
    ) -> BoxStream<'a, Result<(MPathElement, DirectoryBranchClusterManifestEntry)>> {
        self.subentries
            .into_prefix_entries(ctx, blobstore, prefix)
            .map(|res| res.and_then(|(k, v)| anyhow::Ok((MPathElement::from_smallvec(k)?, v))))
            .boxed()
    }

    /// Returns true if this directory is part of a cluster (is a primary or secondary)
    pub fn is_clustered(&self) -> bool {
        self.secondaries.as_ref().is_some_and(|m| !m.is_empty()) || self.primary.is_some()
    }

    /// Returns the secondaries for this directory (paths copied FROM this directory), if any
    pub fn get_secondaries(&self) -> Option<&[MPath]> {
        self.secondaries.as_deref()
    }

    /// Returns the primary for this directory (path this directory was copied FROM), if any
    pub fn get_primary(&self) -> Option<&MPath> {
        self.primary.as_ref()
    }
}

impl BlobstoreValue for DirectoryBranchClusterManifest {
    type Key = DirectoryBranchClusterManifestId;

    fn into_blob(self) -> DirectoryBranchClusterManifestBlob {
        let data = self.into_bytes();
        let id = DirectoryBranchClusterManifestContext::id_from_data(&data);
        Blob::new(id, data)
    }

    fn from_blob(blob: Blob<Self::Key>) -> Result<Self> {
        Self::from_bytes(blob.data())
    }
}
