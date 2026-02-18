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
use crate::blob::ContentManifestBlob;
use crate::sharded_map_v2::ShardedMapV2Node;
use crate::sharded_map_v2::ShardedMapV2Value;
use crate::thrift;
use crate::typed_hash::ContentId;
use crate::typed_hash::ContentManifestId;
use crate::typed_hash::ContentManifestIdContext;
use crate::typed_hash::IdContext;
use crate::typed_hash::ShardedMapV2NodeContentManifestContext;
use crate::typed_hash::ShardedMapV2NodeContentManifestId;

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::content_manifest::ContentManifestFile)]
pub struct ContentManifestFile {
    pub content_id: ContentId,
    pub file_type: FileType,
    pub size: u64,
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::content_manifest::ContentManifestDirectory)]
pub struct ContentManifestDirectory {
    pub id: ContentManifestId,
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::content_manifest::ContentManifestEntry)]
pub enum ContentManifestEntry {
    File(ContentManifestFile),
    Directory(ContentManifestDirectory),
}

#[derive(ThriftConvert, Debug, Clone, PartialEq, Eq, Hash)]
#[thrift(thrift::content_manifest::ContentManifest)]
pub struct ContentManifest {
    pub subentries: ShardedMapV2Node<ContentManifestEntry>,
}

impl ContentManifest {
    pub fn empty() -> Self {
        Self {
            subentries: Default::default(),
        }
    }

    pub async fn lookup(
        &self,
        ctx: &CoreContext,
        blobstore: &impl KeyedBlobstore,
        name: &MPathElement,
    ) -> Result<Option<ContentManifestEntry>> {
        self.subentries.lookup(ctx, blobstore, name.as_ref()).await
    }

    pub fn into_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
    ) -> BoxStream<'a, Result<(MPathElement, ContentManifestEntry)>> {
        self.subentries
            .into_entries(ctx, blobstore)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }

    pub fn into_prefix_subentries<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        prefix: &'a [u8],
    ) -> BoxStream<'a, Result<(MPathElement, ContentManifestEntry)>> {
        self.subentries
            .into_prefix_entries(ctx, blobstore, prefix.as_ref())
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }

    pub fn into_prefix_subentries_after<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        prefix: &'a [u8],
        after: &'a [u8],
    ) -> BoxStream<'a, Result<(MPathElement, ContentManifestEntry)>> {
        self.subentries
            .into_prefix_entries_after(ctx, blobstore, prefix.as_ref(), after.as_ref())
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }

    pub fn into_subentries_skip<'a>(
        self,
        ctx: &'a CoreContext,
        blobstore: &'a impl KeyedBlobstore,
        skip: usize,
    ) -> BoxStream<'a, Result<(MPathElement, ContentManifestEntry)>> {
        self.subentries
            .into_entries_skip(ctx, blobstore, skip)
            .and_then(|(k, v)| async move { anyhow::Ok((MPathElement::from_smallvec(k)?, v)) })
            .boxed()
    }
}

impl BlobstoreValue for ContentManifest {
    type Key = ContentManifestId;

    fn into_blob(self) -> ContentManifestBlob {
        let data = self.into_bytes();
        let id = ContentManifestIdContext::id_from_data(&data);
        Blob::new(id, data)
    }

    fn from_blob(blob: Blob<Self::Key>) -> Result<Self> {
        Self::from_bytes(blob.data())
    }
}

impl ShardedMapV2Value for ContentManifestEntry {
    type NodeId = ShardedMapV2NodeContentManifestId;
    type Context = ShardedMapV2NodeContentManifestContext;
    type RollupData = ();

    const WEIGHT_LIMIT: usize = 2000;
}

pub mod compat {
    use either::Either;

    use crate::ContentId;
    use crate::FileType;
    use crate::fsnode;

    pub type ContentManifestId = Either<super::ContentManifestId, crate::FsnodeId>;

    impl From<super::ContentManifestId> for ContentManifestId {
        fn from(value: super::ContentManifestId) -> Self {
            ContentManifestId::Left(value)
        }
    }

    impl From<crate::FsnodeId> for ContentManifestId {
        fn from(value: crate::FsnodeId) -> Self {
            ContentManifestId::Right(value)
        }
    }

    #[derive(Debug, Clone, PartialEq, Eq, Hash)]
    pub struct ContentManifestFile(pub Either<super::ContentManifestFile, fsnode::FsnodeFile>);

    impl From<super::ContentManifestFile> for ContentManifestFile {
        fn from(value: super::ContentManifestFile) -> Self {
            ContentManifestFile(Either::Left(value))
        }
    }

    impl From<fsnode::FsnodeFile> for ContentManifestFile {
        fn from(value: fsnode::FsnodeFile) -> Self {
            ContentManifestFile(Either::Right(value))
        }
    }

    impl From<Either<super::ContentManifestFile, fsnode::FsnodeFile>> for ContentManifestFile {
        fn from(value: Either<super::ContentManifestFile, fsnode::FsnodeFile>) -> Self {
            ContentManifestFile(value)
        }
    }

    impl ContentManifestFile {
        pub fn content_id(&self) -> ContentId {
            match &self.0 {
                Either::Left(value) => value.content_id,
                Either::Right(value) => *value.content_id(),
            }
        }

        pub fn file_type(&self) -> FileType {
            match &self.0 {
                Either::Left(value) => value.file_type,
                Either::Right(value) => *value.file_type(),
            }
        }

        pub fn size(&self) -> u64 {
            match &self.0 {
                Either::Left(value) => value.size,
                Either::Right(value) => value.size(),
            }
        }
    }
}
