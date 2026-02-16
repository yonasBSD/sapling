/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use context::CoreContext;
use mononoke_types::ChangesetId;

use crate::repo::Repo;

#[allow(dead_code)]
pub struct RebaseResult {
    pub rebased_cs_id: ChangesetId,
}

#[allow(dead_code)]
pub enum RebaseOutcome {
    Success(RebaseResult),
    /// The rebase could not complete because files in the changeset conflict
    /// with changes between old_parent and new_parent.
    Conflict(String),
}

/// Rebase a single changeset onto a new parent.
///
/// Performs a simple parent-swap: the changeset's file changes are preserved
/// but its parent is replaced. If any files changed by the changeset also
/// changed in old_parent..new_parent, returns `Conflict` instead.
#[allow(dead_code)]
pub async fn rebase_changeset(
    _ctx: &CoreContext,
    _repo: &Repo,
    _cs_id: ChangesetId,
    _old_parent: ChangesetId,
    _new_parent: ChangesetId,
) -> Result<RebaseOutcome> {
    unimplemented!("rebase_changeset will be implemented in a subsequent diff")
}
