/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::collections::HashSet;

use anyhow::Result;
use futures::future::try_join_all;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;
use futures::stream::{self};
use mononoke_api::ChangesetContext;
use mononoke_api::MononokeRepo;
use mononoke_api::changeset_path::ChangesetPathHistoryOptions;
use mononoke_types::ChangesetId;
use mononoke_types::NonRootMPath;
use tracing::debug;
use tracing::info;

pub type ChangesetParents = HashMap<ChangesetId, Vec<ChangesetId>>;

/// Represents a path that should be exported until a given changeset, i.e. the
/// HEAD commit for that path.
///
/// When partially copying each relevant changeset to the temporary repo, changes
/// to this path in a given changeset will only be copied if this changeset is
/// an ancestor of the head changeset of that path.
///
/// This head changeset will be used to query the history of the path,
/// i.e. all exported commits that affect this path will be this changeset's
/// ancestor.
pub type ExportPathInfo<R> = (NonRootMPath, ChangesetContext<R>);

pub struct GitExportGraphInfo<R> {
    pub changesets: Vec<ChangesetContext<R>>,
    pub parents_map: ChangesetParents,
}

impl<R> std::fmt::Debug for GitExportGraphInfo<R>
where
    ChangesetContext<R>: std::fmt::Debug,
{
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(
            f,
            "GitExportGraphInfo(changesets={:?}, parents_map={:?})",
            self.changesets, self.parents_map,
        )
    }
}

/// Given a list of paths and a changeset, return a commit graph
/// containing only commits that are ancestors of the changeset and have
/// modified at least one of the paths.
/// The commit graph is returned as a topologically sorted list of changesets
/// and a hashmap of changeset id to their parents' ids.
pub async fn build_partial_commit_graph_for_export<R: MononokeRepo>(
    paths: Vec<ExportPathInfo<R>>,
    // Consider history until the provided timestamp, i.e. all commits in the
    // graph will have its creation time greater than or equal to it.
    oldest_commit_ts: Option<i64>,
) -> Result<GitExportGraphInfo<R>> {
    info!("Building partial commit graph for export...");

    let cs_path_history_options = ChangesetPathHistoryOptions {
        follow_history_across_deletions: true,
        until_timestamp: oldest_commit_ts,
        ..Default::default()
    };

    let history_changesets: Vec<Vec<ChangesetContext<R>>> = stream::iter(paths)
        .then(|(p, cs_ctx)| async move {
            get_relevant_changesets_for_single_path(p, &cs_ctx, &cs_path_history_options).await
        })
        .try_collect::<Vec<_>>()
        .await?;

    let (sorted_changesets, parents_map) =
        merge_cs_lists_and_build_parents_map(history_changesets).await?;

    info!(
        "Number of changesets to export: {0:?}",
        sorted_changesets.len()
    );

    info!("Partial commit graph built!");
    Ok(GitExportGraphInfo {
        parents_map,
        changesets: sorted_changesets,
    })
}

/// Get all changesets that affected the provided path up to a specific head
/// commit.
async fn get_relevant_changesets_for_single_path<R: MononokeRepo>(
    path: NonRootMPath,
    head_cs: &ChangesetContext<R>,
    cs_path_history_opts: &ChangesetPathHistoryOptions,
) -> Result<Vec<ChangesetContext<R>>> {
    let cs_path_hist_ctx = head_cs.path_with_history(path).await?;

    let changesets: Vec<ChangesetContext<R>> = cs_path_hist_ctx
        .history(*cs_path_history_opts)
        .await?
        .try_collect()
        .await?;

    Ok(changesets)
}

/// Given a list of changeset lists, merge, dedupe and sort them topologically
/// into a single changeset list that can be used to partially copy commits
/// to a temporary repo.
/// In the process, also build the hashmap containing the parent information
/// **considering only the exported directories**.
///
/// Example: Given the graph `A -> b -> c -> D -> e`, where commits with uppercase
/// have modified export paths, the parent map should be `{A: [D]}`, because
/// the partial graph is `A -> D`.
///
/// Merge commits in the real DAG are handled by resolving each real parent
/// to its nearest ancestor in the export set. If all real parents resolve
/// to the same export-set ancestor (or have no ancestor), the merge is
/// transparent and the partial graph stays linear. If they resolve to
/// multiple different ancestors, the merge is preserved as an N-parent
/// merge in the partial graph.
async fn merge_cs_lists_and_build_parents_map<R: MononokeRepo>(
    changeset_lists: Vec<Vec<ChangesetContext<R>>>,
) -> Result<(Vec<ChangesetContext<R>>, ChangesetParents)> {
    info!("Merging changeset lists and building parents map...");
    let mut changesets_with_gen: Vec<(ChangesetContext<R>, u64)> =
        stream::iter(changeset_lists.into_iter().flatten())
            .then(|cs| async move {
                let generation = cs.generation().await?.value();
                anyhow::Ok((cs, generation))
            })
            .try_collect::<Vec<_>>()
            .await?;

    // Sort by generation number
    debug!("Sorting changesets by generation number...");
    changesets_with_gen.sort_by_key(|(cs, generation)| (*generation, cs.id()));

    // Collect the sorted changesets
    let mut sorted_css = changesets_with_gen
        .into_iter()
        .map(|(cs, _)| cs)
        .collect::<Vec<_>>();

    // Remove any duplicates from the list.
    // NOTE: `dedup_by` can only be used here because the list is sorted!
    debug!("Deduping changesets...");
    sorted_css.dedup_by_key(|cs| cs.id());

    // Build a set of all changeset IDs in the export set for quick lookup.
    let export_cs_ids: HashSet<ChangesetId> = sorted_css.iter().map(|cs| cs.id()).collect();

    // Build the parents map by resolving actual parent relationships.
    // For each changeset, find its parents in the partial graph by walking
    // backwards through its real Mononoke parents until we find one in the
    // export set. Process changesets concurrently for performance.
    debug!("Building parents map...");
    let parents_map: ChangesetParents =
        stream::iter(sorted_css.iter().enumerate().map(|(idx, cs)| {
            let export_cs_ids = &export_cs_ids;
            let sorted_css = &sorted_css;
            async move {
                let real_parents = cs.parents().await?;

                if real_parents.is_empty() {
                    // Root commit
                    return anyhow::Ok((cs.id(), vec![]));
                }

                // Resolve each real parent to its nearest ancestor in the export set.
                // Parents already in the set map directly; others require walking
                // backwards through the DAG. Results are deduped because multiple
                // real parents may resolve to the same export-set ancestor.
                //
                // Only search among changesets with lower generation (i.e. earlier
                // in the sorted list) since ancestors always have lower generation.
                let ancestors_slice = &sorted_css[..idx];
                let resolved: Vec<Option<ChangesetId>> =
                    try_join_all(real_parents.iter().map(|parent_id| async {
                        if export_cs_ids.contains(parent_id) {
                            Ok(Some(*parent_id))
                        } else {
                            find_nearest_export_ancestor(*parent_id, ancestors_slice).await
                        }
                    }))
                    .await?;
                let mut partial_parents: Vec<ChangesetId> =
                    resolved.into_iter().flatten().collect();
                partial_parents.sort();
                partial_parents.dedup();

                Ok((cs.id(), partial_parents))
            }
        }))
        .buffer_unordered(100)
        .try_collect::<HashMap<_, _>>()
        .await?;

    Ok((sorted_css, parents_map))
}

/// Find the nearest ancestor of `start_parent_id` that is in the export set.
/// `candidates` must only contain changesets with lower generation than the
/// commit being processed (i.e. the caller passes `&sorted_css[..idx]`).
async fn find_nearest_export_ancestor<R: MononokeRepo>(
    start_parent_id: ChangesetId,
    candidates: &[ChangesetContext<R>],
) -> Result<Option<ChangesetId>> {
    // Search backwards (newest first) to find the most recent ancestor.
    for candidate in candidates.iter().rev() {
        if candidate.is_ancestor_of(start_parent_id).await? {
            return Ok(Some(candidate.id()));
        }
    }
    // No ancestor found in the export set — this is a root in the partial graph
    Ok(None)
}
