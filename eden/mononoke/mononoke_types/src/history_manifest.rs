/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use blobstore::KeyedBlobstore;
use context::CoreContext;
use futures::stream::BoxStream;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;

use crate::FileType;
use crate::MPathElement;
use crate::ThriftConvert;
use crate::blob::Blob;
use crate::blob::BlobstoreValue;
use crate::blob::HistoryManifestDeletedNodeBlob;
use crate::blob::HistoryManifestDirectoryBlob;
use crate::blob::HistoryManifestFileBlob;
use crate::path::MPathHash;
use crate::sharded_map_v2::ShardedMapV2Node;
use crate::sharded_map_v2::ShardedMapV2Value;
use crate::thrift;
use crate::typed_hash::ChangesetId;
use crate::typed_hash::ContentId;
use crate::typed_hash::HistoryManifestDeletedNodeId;
use crate::typed_hash::HistoryManifestDeletedNodeIdContext;
use crate::typed_hash::HistoryManifestDirectoryId;
use crate::typed_hash::HistoryManifestDirectoryIdContext;
use crate::typed_hash::HistoryManifestFileId;
use crate::typed_hash::HistoryManifestFileIdContext;
use crate::typed_hash::IdContext;
use crate::typed_hash::ShardedMapV2NodeHistoryManifestContext;
use crate::typed_hash::ShardedMapV2NodeHistoryManifestId;

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::history_manifest::HistoryManifestEntry)]
pub enum HistoryManifestEntry {
    File(HistoryManifestFileId),
    Directory(HistoryManifestDirectoryId),
    DeletedNode(HistoryManifestDeletedNodeId),
}

impl ShardedMapV2Value for HistoryManifestEntry {
    type NodeId = ShardedMapV2NodeHistoryManifestId;
    type Context = ShardedMapV2NodeHistoryManifestContext;
    type RollupData = ();

    // TODO: Work out what the best weight is here before backfilling.
    const WEIGHT_LIMIT: usize = 2000;
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct HistoryManifestFile {
    pub parents: Vec<HistoryManifestEntry>,
    pub content_id: ContentId,
    pub file_type: FileType,
    pub path_hash: MPathHash,
    pub linknode: ChangesetId,
    pub subentries: ShardedMapV2Node<HistoryManifestEntry>,
}

impl ThriftConvert for HistoryManifestFile {
    const NAME: &'static str = "HistoryManifestFile";
    type Thrift = thrift::history_manifest::HistoryManifestFile;

    fn from_thrift(t: Self::Thrift) -> Result<Self> {
        let parents: Result<Vec<_>> = t
            .parents
            .into_iter()
            .map(HistoryManifestEntry::from_thrift)
            .collect();
        Ok(Self {
            parents: parents?,
            content_id: ContentId::from_thrift(t.content_id)?,
            file_type: FileType::from_thrift(t.file_type)?,
            path_hash: MPathHash::from_thrift(t.path_hash)?,
            linknode: ChangesetId::from_thrift(t.linknode)?,
            subentries: ShardedMapV2Node::from_thrift(t.subentries)?,
        })
    }

    fn into_thrift(self) -> Self::Thrift {
        thrift::history_manifest::HistoryManifestFile {
            parents: self
                .parents
                .into_iter()
                .map(HistoryManifestEntry::into_thrift)
                .collect(),
            content_id: self.content_id.into_thrift(),
            file_type: self.file_type.into_thrift(),
            path_hash: self.path_hash.into_thrift(),
            linknode: self.linknode.into_thrift(),
            subentries: self.subentries.into_thrift(),
        }
    }
}

impl HistoryManifestFile {
    pub fn get_file_id(&self) -> HistoryManifestFileId {
        *self.clone().into_blob().id()
    }

    pub async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &impl KeyedBlobstore,
        name: &MPathElement,
    ) -> Result<Option<HistoryManifestEntry>> {
        self.subentries.lookup(ctx, blobstore, name.as_ref()).await
    }

    pub fn into_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
        self.subentries
            .into_entries(ctx, blobstore)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }
}

impl BlobstoreValue for HistoryManifestFile {
    type Key = HistoryManifestFileId;

    fn into_blob(self) -> HistoryManifestFileBlob {
        let data = self.into_bytes();
        let id = HistoryManifestFileIdContext::id_from_data(&data);
        Blob::new(id, data)
    }

    fn from_blob(blob: Blob<Self::Key>) -> Result<Self> {
        Self::from_bytes(blob.data())
    }
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::history_manifest::HistoryManifestDeletedNode)]
pub struct HistoryManifestDeletedNode {
    pub parents: Vec<HistoryManifestEntry>,
    pub subentries: ShardedMapV2Node<HistoryManifestEntry>,
    pub linknode: ChangesetId,
}

impl HistoryManifestDeletedNode {
    pub fn into_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
        self.subentries
            .into_entries(ctx, blobstore)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }
}

impl BlobstoreValue for HistoryManifestDeletedNode {
    type Key = HistoryManifestDeletedNodeId;

    fn into_blob(self) -> HistoryManifestDeletedNodeBlob {
        let data = self.into_bytes();
        let id = HistoryManifestDeletedNodeIdContext::id_from_data(&data);
        Blob::new(id, data)
    }

    fn from_blob(blob: Blob<Self::Key>) -> Result<Self> {
        Self::from_bytes(blob.data())
    }
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::history_manifest::HistoryManifestDirectory)]
pub struct HistoryManifestDirectory {
    pub parents: Vec<HistoryManifestEntry>,
    pub subentries: ShardedMapV2Node<HistoryManifestEntry>,
    pub linknode: ChangesetId,
}

impl HistoryManifestDirectory {
    pub fn empty(parents: Vec<HistoryManifestEntry>, linknode: ChangesetId) -> Self {
        Self {
            parents,
            subentries: Default::default(),
            linknode,
        }
    }

    pub fn get_directory_id(&self) -> HistoryManifestDirectoryId {
        *self.clone().into_blob().id()
    }

    pub async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &impl KeyedBlobstore,
        name: &MPathElement,
    ) -> Result<Option<HistoryManifestEntry>> {
        self.subentries.lookup(ctx, blobstore, name.as_ref()).await
    }

    pub fn into_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
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
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
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
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
        self.subentries
            .into_prefix_entries(ctx, blobstore, prefix)
            .map(|res| res.and_then(|(k, v)| anyhow::Ok((MPathElement::from_smallvec(k)?, v))))
            .boxed()
    }

    pub fn into_prefix_subentries_after<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        prefix: &'a [u8],
        after: &'a [u8],
    ) -> BoxStream<'a, Result<(MPathElement, HistoryManifestEntry)>> {
        self.subentries
            .into_prefix_entries_after(ctx, blobstore, prefix, after)
            .map(|res| res.and_then(|(k, v)| anyhow::Ok((MPathElement::from_smallvec(k)?, v))))
            .boxed()
    }
}

impl BlobstoreValue for HistoryManifestDirectory {
    type Key = HistoryManifestDirectoryId;

    fn into_blob(self) -> HistoryManifestDirectoryBlob {
        let data = self.into_bytes();
        let id = HistoryManifestDirectoryIdContext::id_from_data(&data);
        Blob::new(id, data)
    }

    fn from_blob(blob: Blob<Self::Key>) -> Result<Self> {
        Self::from_bytes(blob.data())
    }
}
