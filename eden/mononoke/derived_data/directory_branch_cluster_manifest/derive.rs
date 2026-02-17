/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;

use anyhow::Result;
use context::CoreContext;
use derived_data_manager::DerivationContext;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::typed_hash::DirectoryBranchClusterManifestId;

use crate::mapping::RootDirectoryBranchClusterManifestId;

pub(crate) async fn derive_single(
    _ctx: &CoreContext,
    _derivation_ctx: &DerivationContext,
    _bonsai: BonsaiChangeset,
    _parents: Vec<RootDirectoryBranchClusterManifestId>,
    _known: Option<&HashMap<ChangesetId, RootDirectoryBranchClusterManifestId>>,
) -> Result<RootDirectoryBranchClusterManifestId> {
    // TODO: Implement actual derivation logic
    Ok(RootDirectoryBranchClusterManifestId(
        DirectoryBranchClusterManifestId::from_bytes([0u8; 32])?,
    ))
}
