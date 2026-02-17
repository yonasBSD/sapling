/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! Derivation logic for the Directory Branch Cluster Manifest (DBCM).
//!
//! The DBCM tracks "clusters" of directories that share content due to subtree
//! copy or merge operations. Each cluster has one primary (the original source)
//! and zero or more secondaries (the copies/merge targets).
//!
//! # Manifest Structure
//!
//! The manifest is a tree where each directory entry stores:
//! - `primary`: If this directory was copied/merged from another, points to the source
//! - `secondaries`: List of directories that were copied/merged from this one
//!
//! Unlike other manifests, DBCM only stores directories (no files). It tracks
//! cluster relationships between directories, which files don't have.
//!
//! # Example
//!
//! Consider a repository with these directories after several operations:
//!
//! ```text
//! Initial state: directories A, B, C, D exist independently
//!
//! Commit 1: Subtree Copy A → B
//! Commit 2: Subtree Copy A → C
//! Commit 3: Subtree Merge D → A
//! ```
//!
//! After these commits, the manifest looks like:
//!
//! ```text
//! Root
//! ├── A: { primary: None, secondaries: [B, C, D] }
//! ├── B: { primary: A, secondaries: None }
//! ├── C: { primary: A, secondaries: None }
//! └── D: { primary: A, secondaries: None }
//! ```
//!
//! All four directories form a single cluster with A as the primary.

use std::collections::HashMap;
use std::sync::Arc;

use anyhow::Result;
use blobstore::KeyedBlobstore;
use context::CoreContext;
use derived_data_manager::DerivationContext;
use futures::TryStreamExt;
use futures::future::BoxFuture;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::MPath;
use mononoke_types::MPathElement;
use mononoke_types::TrieMap;
use mononoke_types::directory_branch_cluster_manifest::DirectoryBranchClusterManifest;
use mononoke_types::sharded_map_v2::ShardedMapV2Node;
use mononoke_types::typed_hash::DirectoryBranchClusterManifestId;

use crate::RootDirectoryBranchClusterManifestId;

/// Merge multiple parent manifests into a single base manifest.
/// No cluster changes are applied - just combines parent state.
pub async fn merge_parent_manifests(
    ctx: &CoreContext,
    blobstore: &Arc<dyn KeyedBlobstore>,
    parents: Vec<DirectoryBranchClusterManifest>,
) -> Result<DirectoryBranchClusterManifest> {
    if parents.is_empty() {
        return Ok(DirectoryBranchClusterManifest::empty());
    }
    if parents.len() == 1 {
        return Ok(parents.into_iter().next().unwrap());
    }
    merge_manifests_recursive(ctx, blobstore, parents, MPath::ROOT).await
}

/// Recursively merge parent manifests at a given path.
fn merge_manifests_recursive<'a>(
    ctx: &'a CoreContext,
    blobstore: &'a Arc<dyn KeyedBlobstore>,
    parents: Vec<DirectoryBranchClusterManifest>,
    current_path: MPath,
) -> BoxFuture<'a, Result<DirectoryBranchClusterManifest>> {
    Box::pin(async move {
        // Collect all child path elements from all parents
        let mut child_elements: std::collections::HashSet<MPathElement> =
            std::collections::HashSet::new();

        // Collect children from parents
        let mut parent_child_entries: HashMap<MPathElement, Vec<DirectoryBranchClusterManifest>> =
            HashMap::new();
        for parent in &parents {
            let parent_entries: Vec<_> = parent
                .clone()
                .into_subentries(ctx, blobstore)
                .try_collect()
                .await?;
            for (elem, dir) in parent_entries {
                child_elements.insert(elem.clone());
                parent_child_entries.entry(elem).or_default().push(dir);
            }
        }

        // Build entries for each child
        let mut entries: HashMap<MPathElement, DirectoryBranchClusterManifest> = HashMap::new();

        for elem in child_elements {
            let child_path = current_path.join_element(Some(&elem));
            let child_parent_entries = parent_child_entries.remove(&elem).unwrap_or_default();

            if child_parent_entries.len() > 1 {
                // Multiple parents have this entry - need to recurse and merge
                let child_manifest =
                    merge_manifests_recursive(ctx, blobstore, child_parent_entries, child_path)
                        .await?;

                entries.insert(elem, child_manifest);
            } else if let Some(single_parent_entry) = child_parent_entries.into_iter().next() {
                // Single parent has this entry - just copy through
                entries.insert(elem, single_parent_entry);
            }
        }

        // Build the final manifest at this level
        let subentries_trie: TrieMap<_> = entries
            .into_iter()
            .map(|(name, dir)| (name.to_smallvec(), itertools::Either::Left(dir)))
            .collect();

        let subentries =
            ShardedMapV2Node::from_entries_and_partial_maps(ctx, blobstore, subentries_trie)
                .await?;

        // Merge parent cluster info at this level
        let mut merged_primary: Option<MPath> = None;
        let mut merged_secondaries: Option<Vec<MPath>> = None;

        for parent in &parents {
            if merged_primary.is_none() {
                merged_primary = parent.primary.clone();
            }
            if let Some(ref parent_secs) = parent.secondaries {
                let mut secs = merged_secondaries.take().unwrap_or_default();
                secs.extend(parent_secs.iter().cloned());
                secs.sort();
                secs.dedup();
                merged_secondaries = Some(secs);
            }
        }

        Ok(DirectoryBranchClusterManifest {
            subentries,
            secondaries: merged_secondaries,
            primary: merged_primary,
        })
    })
}

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
