/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use thiserror::Error;

mod derive;
mod mapping;
mod merge_subtrees;

pub use crate::mapping::RootHistoryManifestDirectoryId;

#[derive(Debug, Error)]
pub enum HistoryManifestDerivationError {
    #[error("Invalid bonsai changeset: root of history manifest must be an existing directory")]
    InvalidRootDirectory,

    #[error("Invalid bonsai changeset: inconsistent merge")]
    InconsistentMerge,
}
