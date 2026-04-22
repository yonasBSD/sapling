/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;

use anyhow::Error;
use anyhow::Result;
use anyhow::anyhow;
use async_trait::async_trait;
use blobstore::BlobstoreGetData;
use bytes::Bytes;
use context::CoreContext;
use derived_data_manager::BonsaiDerivable;
use derived_data_manager::DerivableType;
use derived_data_manager::DerivationContext;
use derived_data_manager::dependencies;
use derived_data_service_if as thrift;
use mononoke_types::BlobstoreBytes;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::HistoryManifestDirectoryId;

#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct RootHistoryManifestDirectoryId(pub(crate) HistoryManifestDirectoryId);

impl RootHistoryManifestDirectoryId {
    pub fn into_history_manifest_directory_id(self) -> HistoryManifestDirectoryId {
        self.0
    }
}

impl TryFrom<BlobstoreBytes> for RootHistoryManifestDirectoryId {
    type Error = Error;

    fn try_from(value: BlobstoreBytes) -> Result<Self> {
        Ok(RootHistoryManifestDirectoryId(
            HistoryManifestDirectoryId::from_bytes(value.into_bytes())?,
        ))
    }
}

impl TryFrom<BlobstoreGetData> for RootHistoryManifestDirectoryId {
    type Error = Error;

    fn try_from(value: BlobstoreGetData) -> Result<Self> {
        value.into_bytes().try_into()
    }
}

impl From<RootHistoryManifestDirectoryId> for BlobstoreBytes {
    fn from(value: RootHistoryManifestDirectoryId) -> Self {
        BlobstoreBytes::from_bytes(Bytes::copy_from_slice(value.0.blake2().as_ref()))
    }
}

pub fn format_key(derivation_ctx: &DerivationContext, changeset_id: ChangesetId) -> String {
    let key_prefix = derivation_ctx.mapping_key_prefix::<RootHistoryManifestDirectoryId>();
    format!("derived_root_history_manifest.{key_prefix}{changeset_id}")
}

#[async_trait]
impl BonsaiDerivable for RootHistoryManifestDirectoryId {
    const VARIANT: DerivableType = DerivableType::HistoryManifests;

    type Dependencies = dependencies![];

    async fn derive_single(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        bonsai: BonsaiChangeset,
        parents: Vec<Self>,
        known: Option<&HashMap<ChangesetId, Self>>,
    ) -> Result<Self> {
        let cs_id = bonsai.get_changeset_id();
        let parent_ids = parents.into_iter().map(|p| p.0).collect();
        let id = crate::derive::derive_history_manifest(
            ctx,
            derivation_ctx,
            known,
            cs_id,
            &bonsai,
            parent_ids,
        )
        .await?;
        Ok(RootHistoryManifestDirectoryId(id))
    }

    async fn store_mapping(
        self,
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        changeset_id: ChangesetId,
    ) -> Result<()> {
        let key = format_key(derivation_ctx, changeset_id);
        derivation_ctx.blobstore().put(ctx, key, self.into()).await
    }

    async fn fetch(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        changeset_id: ChangesetId,
    ) -> Result<Option<Self>> {
        let key = format_key(derivation_ctx, changeset_id);
        Ok(derivation_ctx
            .blobstore()
            .get(ctx, &key)
            .await?
            .map(TryInto::try_into)
            .transpose()?)
    }

    fn from_thrift(data: thrift::DerivedData) -> Result<Self> {
        if let thrift::DerivedData::history_manifest(
            thrift::DerivedDataHistoryManifest::root_history_manifest_directory_id(id),
        ) = data
        {
            Ok(RootHistoryManifestDirectoryId(
                HistoryManifestDirectoryId::from_thrift(id)?,
            ))
        } else {
            Err(anyhow!(
                "Can't convert {} from provided thrift::DerivedData",
                Self::NAME,
            ))
        }
    }

    fn into_thrift(data: Self) -> Result<thrift::DerivedData> {
        Ok(thrift::DerivedData::history_manifest(
            thrift::DerivedDataHistoryManifest::root_history_manifest_directory_id(
                data.into_history_manifest_directory_id().into_thrift(),
            ),
        ))
    }
}
