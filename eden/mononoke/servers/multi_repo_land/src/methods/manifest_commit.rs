/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use bytes::Bytes;
use context::CoreContext;
use mononoke_types::ChangesetId;
use mononoke_types::NonRootMPath;

use crate::repo::Repo;

/// Create a commit that updates the manifest file on top of a parent changeset.
///
/// The commit is stored in the blobstore but no bookmark points to it yet.
/// The caller is responsible for moving the bookmark as part of the atomic
/// multi-repo transaction.
#[allow(dead_code)]
pub async fn create_manifest_commit(
    _ctx: &CoreContext,
    _repo: &Repo,
    _parent: ChangesetId,
    _manifest_path: &NonRootMPath,
    _manifest_content: Bytes,
    _service_identity: &str,
) -> Result<ChangesetId> {
    unimplemented!("create_manifest_commit will be implemented in a subsequent diff")
}
