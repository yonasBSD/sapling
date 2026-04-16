/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::num::NonZeroU32;
use std::sync::Arc;

use anyhow::Result;
use anyhow::anyhow;
use async_trait::async_trait;
use blobstore::Blobstore;
use bytes::Bytes;
use cloned::cloned;
use commit_graph_thrift as thrift;
use commit_graph_types::edges::ChangesetEdges;
use commit_graph_types::edges::ChangesetEdgesMut;
use commit_graph_types::edges::ChangesetNode;
use commit_graph_types::edges::CompactChangesetEdges;
use commit_graph_types::edges::FirstParentLinear;
use commit_graph_types::edges::Parents;
use commit_graph_types::edges::ParentsAndSubtreeSources;
use commit_graph_types::storage::CommitGraphStorage;
use commit_graph_types::storage::FetchedChangesetEdges;
use commit_graph_types::storage::Prefetch;
use context::CoreContext;
use fbthrift::compact_protocol;
use mononoke_macros::mononoke;
use mononoke_types::ChangesetId;
use mononoke_types::ChangesetIdPrefix;
use mononoke_types::ChangesetIdsResolvedFromPrefix;
use mononoke_types::Generation;
use reloader::Loader;
use reloader::Reloader;
use repo_identity::ArcRepoIdentity;
use smallvec::SmallVec;
use tracing::info;
use vec1::Vec1;

#[cfg(test)]
mod tests;

const DEFAULT_RELOADING_INTERVAL_SECS: u64 = 60 * 60;

/// A commit graph storage that wraps another storage and periodically preloads
/// the changeset edges of the commit graph from the blobstore. Writes are passed
/// to the underlying storage, while reads first search the preloaded changeset
/// edges and fall over to the underlying storage for the missing changesets.
///
/// Useful for commit graphs with complicated structure that are small enough
/// to fit into memory.
pub struct PreloadedCommitGraphStorage {
    preloaded_edges: Arc<Reloader<PreloadedEdges>>,
    persistent_storage: Arc<dyn CommitGraphStorage>,
}

pub struct PreloadedEdgesLoader {
    ctx: CoreContext,
    blobstore_without_cache: Arc<dyn Blobstore>,
    blobstore_key: String,
}

#[derive(Debug, Default)]
pub struct PreloadedEdges {
    /// Maps changeset ID to index in the edges vector.
    pub cs_id_to_idx: HashMap<ChangesetId, u32>,
    /// All changeset edges, indexed by position. The unique_id maps to index + 1
    /// (since unique_id is NonZeroU32).
    pub edges: Vec<CompactChangesetEdges>,
    pub max_sql_id: Option<u64>,
}

impl PreloadedEdges {
    pub fn to_thrift(&self) -> Result<thrift::PreloadedEdges> {
        Ok(thrift::PreloadedEdges {
            edges: self
                .edges
                .iter()
                .enumerate()
                .map(|(idx, edge)| {
                    let unique_id = NonZeroU32::new((idx as u32) + 1)
                        .ok_or_else(|| anyhow!("Invalid index for unique_id"))?;
                    Ok(edge.to_thrift(unique_id))
                })
                .collect::<Result<_>>()?,
            max_sql_id: self.max_sql_id.map(|id| id as i64),
        })
    }

    pub fn from_thrift(preloaded_edges: thrift::PreloadedEdges) -> Result<Self> {
        let mut cs_id_to_idx = HashMap::with_capacity(preloaded_edges.edges.len());
        let mut edges = Vec::with_capacity(preloaded_edges.edges.len());

        for edge in preloaded_edges.edges {
            let compact_edge = CompactChangesetEdges::from_thrift(edge)?;
            let idx = edges.len() as u32;
            cs_id_to_idx.insert(compact_edge.cs_id, idx);
            edges.push(compact_edge);
        }

        Ok(Self {
            cs_id_to_idx,
            edges,
            max_sql_id: preloaded_edges.max_sql_id.map(|id| id as u64),
        })
    }

    fn get_node(&self, unique_id: NonZeroU32) -> Result<ChangesetNode> {
        let idx = (unique_id.get() - 1) as usize;
        let edge = self
            .edges
            .get(idx)
            .ok_or_else(|| anyhow!("Missing changeset edges for unique id: {}", unique_id))?;

        Ok(ChangesetNode::new(
            edge.cs_id,
            Generation::new(edge.generation as u64),
            Generation::new(edge.subtree_source_generation as u64),
            edge.skip_tree_depth as u64,
            edge.p1_linear_depth as u64,
            edge.subtree_source_depth as u64,
        ))
    }

    pub fn get(
        &self,
        cs_id: &ChangesetId,
        should_apply_fallback: bool,
    ) -> Result<Option<ChangesetEdges>> {
        let compact_edges = match self.cs_id_to_idx.get(cs_id) {
            Some(&idx) => self
                .edges
                .get(idx as usize)
                .ok_or_else(|| anyhow!("Missing changeset edges for index: {}", idx))?,
            None => return Ok(None),
        };

        let mut edges = ChangesetEdgesMut {
            node: ChangesetNode::new(
                *cs_id,
                Generation::new(compact_edges.generation as u64),
                Generation::new(compact_edges.subtree_source_generation as u64),
                compact_edges.skip_tree_depth as u64,
                compact_edges.p1_linear_depth as u64,
                compact_edges.subtree_source_depth as u64,
            ),
            parents: compact_edges
                .parents
                .iter()
                .map(|parent_id| self.get_node(*parent_id))
                .collect::<Result<_>>()?,
            subtree_sources: compact_edges
                .subtree_sources
                .iter()
                .map(|subtree_source_id| self.get_node(*subtree_source_id))
                .collect::<Result<_>>()?,
            merge_ancestor_or_root: compact_edges
                .merge_ancestor_or_root
                .map(|merge_ancestor_or_root| self.get_node(merge_ancestor_or_root))
                .transpose()?,
            skip_tree_parent: compact_edges
                .skip_tree_parent
                .map(|skip_tree_parent| self.get_node(skip_tree_parent))
                .transpose()?,
            skip_tree_skew_ancestor: compact_edges
                .skip_tree_skew_ancestor
                .map(|skip_tree_skew_ancestor| self.get_node(skip_tree_skew_ancestor))
                .transpose()?,
            p1_linear_skew_ancestor: compact_edges
                .p1_linear_skew_ancestor
                .map(|p1_linear_skew_ancestor| self.get_node(p1_linear_skew_ancestor))
                .transpose()?,
            subtree_or_merge_ancestor: compact_edges
                .subtree_or_merge_ancestor
                .map(|subtree_or_merge_ancestor| self.get_node(subtree_or_merge_ancestor))
                .transpose()?,
            subtree_source_parent: compact_edges
                .subtree_source_parent
                .map(|subtree_source_parent| self.get_node(subtree_source_parent))
                .transpose()?,
            subtree_source_skew_ancestor: compact_edges
                .subtree_source_skew_ancestor
                .map(|subtree_source_skew_ancestor| self.get_node(subtree_source_skew_ancestor))
                .transpose()?,
        }
        .freeze();

        if should_apply_fallback {
            edges.apply_subtree_source_fallback();
        }

        Ok(Some(edges))
    }
}

#[derive(Debug, Default)]
pub struct ExtendablePreloadedEdges {
    preloaded_edges: PreloadedEdges,
}

impl ExtendablePreloadedEdges {
    pub fn from_preloaded_edges(preloaded_edges: PreloadedEdges) -> Self {
        Self { preloaded_edges }
    }

    pub fn into_preloaded_edges(self) -> PreloadedEdges {
        self.preloaded_edges
    }

    pub fn unique_id(&mut self, cs_id: ChangesetId) -> NonZeroU32 {
        match self.preloaded_edges.cs_id_to_idx.get(&cs_id) {
            Some(&idx) => NonZeroU32::new(idx + 1).unwrap(),
            None => {
                let idx = self.preloaded_edges.edges.len() as u32;
                self.preloaded_edges.cs_id_to_idx.insert(cs_id, idx);
                self.preloaded_edges.edges.push(CompactChangesetEdges {
                    cs_id,
                    generation: 0,
                    subtree_source_generation: 0,
                    skip_tree_depth: 0,
                    p1_linear_depth: 0,
                    subtree_source_depth: 0,
                    parents: SmallVec::new(),
                    subtree_sources: SmallVec::new(),
                    merge_ancestor_or_root: None,
                    skip_tree_parent: None,
                    skip_tree_skew_ancestor: None,
                    p1_linear_skew_ancestor: None,
                    subtree_or_merge_ancestor: None,
                    subtree_source_parent: None,
                    subtree_source_skew_ancestor: None,
                });
                NonZeroU32::new(idx + 1).unwrap()
            }
        }
    }

    pub fn add(&mut self, edges: ChangesetEdges) -> Result<()> {
        let _unique_id = self.unique_id(edges.node().cs_id);
        let parents = edges
            .parents::<Parents>()
            .map(|parent| self.unique_id(parent.cs_id))
            .collect();
        let subtree_sources = edges
            .subtree_sources()
            .map(|subtree_source| self.unique_id(subtree_source.cs_id))
            .collect();
        let merge_ancestor_or_root = edges
            .merge_ancestor_or_root::<Parents>()
            .map(|merge_ancestor_or_root| self.unique_id(merge_ancestor_or_root.cs_id));
        let skip_tree_parent = edges
            .skip_tree_parent::<Parents>()
            .map(|skip_tree_parent| self.unique_id(skip_tree_parent.cs_id));
        let skip_tree_skew_ancestor = edges
            .skip_tree_skew_ancestor::<Parents>()
            .map(|skip_tree_skew_ancestor| self.unique_id(skip_tree_skew_ancestor.cs_id));
        let p1_linear_skew_ancestor = edges
            .skip_tree_skew_ancestor::<FirstParentLinear>()
            .map(|p1_linear_skew_ancestor| self.unique_id(p1_linear_skew_ancestor.cs_id));
        let subtree_or_merge_ancestor = edges
            .merge_ancestor_or_root::<ParentsAndSubtreeSources>()
            .map(|subtree_or_merge_ancestor| self.unique_id(subtree_or_merge_ancestor.cs_id));
        let subtree_source_parent = edges
            .skip_tree_parent::<ParentsAndSubtreeSources>()
            .map(|subtree_source_parent| self.unique_id(subtree_source_parent.cs_id));
        let subtree_source_skew_ancestor = edges
            .skip_tree_skew_ancestor::<ParentsAndSubtreeSources>()
            .map(|subtree_source_skew_ancestor| self.unique_id(subtree_source_skew_ancestor.cs_id));

        let cs_id = edges.node().cs_id;
        let &idx = self
            .preloaded_edges
            .cs_id_to_idx
            .get(&cs_id)
            .ok_or_else(|| anyhow!("Missing index for changeset: {}", cs_id))?;
        let entry = self
            .preloaded_edges
            .edges
            .get_mut(idx as usize)
            .ok_or_else(|| anyhow!("Missing changeset edges for index: {}", idx))?;
        *entry = CompactChangesetEdges {
            cs_id: edges.node().cs_id,
            generation: edges.node().generation::<Parents>().value() as u32,
            subtree_source_generation: edges
                .node()
                .generation::<ParentsAndSubtreeSources>()
                .value() as u32,
            skip_tree_depth: edges.node().skip_tree_depth::<Parents>() as u32,
            p1_linear_depth: edges.node().skip_tree_depth::<FirstParentLinear>() as u32,
            subtree_source_depth: edges.node().skip_tree_depth::<ParentsAndSubtreeSources>() as u32,
            parents,
            subtree_sources,
            merge_ancestor_or_root,
            skip_tree_parent,
            skip_tree_skew_ancestor,
            p1_linear_skew_ancestor,
            subtree_or_merge_ancestor,
            subtree_source_parent,
            subtree_source_skew_ancestor,
        };

        Ok(())
    }

    pub fn update_max_sql_id(&mut self, max_sql_id: u64) {
        self.preloaded_edges.max_sql_id = Some(max_sql_id);
    }
}

pub fn deserialize_preloaded_edges(bytes: Bytes) -> Result<PreloadedEdges> {
    let preloaded_edges: thrift::PreloadedEdges = compact_protocol::deserialize(bytes)?;

    PreloadedEdges::from_thrift(preloaded_edges)
}

#[async_trait]
impl Loader<PreloadedEdges> for PreloadedEdgesLoader {
    async fn load(&mut self) -> Result<Option<PreloadedEdges>> {
        mononoke::spawn_task({
            cloned!(self.ctx, self.blobstore_without_cache, self.blobstore_key);
            async move {
                info!("Started preloading commit graph");
                let maybe_bytes = blobstore_without_cache.get(&ctx, &blobstore_key).await?;
                match maybe_bytes {
                    Some(bytes) => {
                        let bytes = bytes.into_raw_bytes();
                        let preloaded_edges =
                            tokio::task::spawn_blocking(move || deserialize_preloaded_edges(bytes))
                                .await??;
                        info!(
                            "Finished preloading commit graph ({} changesets)",
                            preloaded_edges.edges.len()
                        );
                        Ok(Some(preloaded_edges))
                    }
                    None => Ok(Some(Default::default())),
                }
            }
        })
        .await?
    }
}

impl PreloadedCommitGraphStorage {
    /// Create just the reloader for preloaded edges, without constructing
    /// the full storage. Useful for caching the reloader independently.
    pub async fn create_reloader(
        ctx: &CoreContext,
        blobstore_without_cache: Arc<dyn Blobstore>,
        preloaded_edges_blobstore_key: String,
    ) -> Result<Arc<Reloader<PreloadedEdges>>> {
        let loader = PreloadedEdgesLoader {
            ctx: ctx.clone(),
            blobstore_key: preloaded_edges_blobstore_key,
            blobstore_without_cache,
        };

        Reloader::reload_periodically(
            ctx.clone(),
            move || {
                std::time::Duration::from_secs(
                    justknobs::get_as::<u64>(
                        "scm/mononoke:preloaded_commit_graph_reloading_interval_secs",
                        None,
                    )
                    .unwrap_or(DEFAULT_RELOADING_INTERVAL_SECS),
                )
            },
            loader,
        )
        .await
        .map(Arc::new)
    }

    /// Construct a PreloadedCommitGraphStorage from an existing reloader
    /// and persistent storage.
    pub fn from_reloader(
        preloaded_edges: Arc<Reloader<PreloadedEdges>>,
        persistent_storage: Arc<dyn CommitGraphStorage>,
    ) -> Arc<Self> {
        Arc::new(Self {
            preloaded_edges,
            persistent_storage,
        })
    }

    pub async fn from_blobstore(
        ctx: &CoreContext,
        blobstore_without_cache: Arc<dyn Blobstore>,
        preloaded_edges_blobstore_key: String,
        persistent_storage: Arc<dyn CommitGraphStorage>,
    ) -> Result<Arc<Self>> {
        let reloader =
            Self::create_reloader(ctx, blobstore_without_cache, preloaded_edges_blobstore_key)
                .await?;
        Ok(Self::from_reloader(reloader, persistent_storage))
    }

    /// Check if fallback should be applied for this repository
    fn should_apply_fallback(&self) -> Result<bool> {
        Ok(!justknobs::eval(
            "scm/mononoke:commit_graph_disable_subtree_source_fallback",
            None,
            Some(self.repo_name()),
        )?)
    }
}

#[async_trait]
impl CommitGraphStorage for PreloadedCommitGraphStorage {
    fn repo_identity(&self) -> &ArcRepoIdentity {
        self.persistent_storage.repo_identity()
    }

    async fn add(&self, ctx: &CoreContext, edges: ChangesetEdges) -> Result<bool> {
        self.persistent_storage.add(ctx, edges).await
    }

    async fn add_many(&self, ctx: &CoreContext, many_edges: Vec1<ChangesetEdges>) -> Result<usize> {
        self.persistent_storage.add_many(ctx, many_edges).await
    }

    async fn fetch_edges(&self, ctx: &CoreContext, cs_id: ChangesetId) -> Result<ChangesetEdges> {
        match self
            .preloaded_edges
            .load()
            .get(&cs_id, self.should_apply_fallback()?)?
        {
            Some(edges) => Ok(edges),
            None => self.persistent_storage.fetch_edges(ctx, cs_id).await,
        }
    }

    async fn maybe_fetch_edges(
        &self,
        ctx: &CoreContext,
        cs_id: ChangesetId,
    ) -> Result<Option<ChangesetEdges>> {
        match self
            .preloaded_edges
            .load()
            .get(&cs_id, self.should_apply_fallback()?)?
        {
            Some(edges) => Ok(Some(edges)),
            None => self.persistent_storage.maybe_fetch_edges(ctx, cs_id).await,
        }
    }

    async fn fetch_many_edges(
        &self,
        ctx: &CoreContext,
        cs_ids: &[ChangesetId],
        prefetch: Prefetch,
    ) -> Result<HashMap<ChangesetId, FetchedChangesetEdges>> {
        let edges = self.maybe_fetch_many_edges(ctx, cs_ids, prefetch).await?;
        if let Some(missing_changeset) = cs_ids.iter().find(|cs_id| !edges.contains_key(cs_id)) {
            Err(anyhow!(
                "Missing changeset from preloaded commit graph storage: {}",
                missing_changeset,
            ))
        } else {
            Ok(edges)
        }
    }

    async fn maybe_fetch_many_edges(
        &self,
        ctx: &CoreContext,
        cs_ids: &[ChangesetId],
        prefetch: Prefetch,
    ) -> Result<HashMap<ChangesetId, FetchedChangesetEdges>> {
        let preloaded_edges = self.preloaded_edges.load();
        let should_apply_fallback = self.should_apply_fallback()?;
        let mut fetched_edges: HashMap<_, _> = cs_ids
            .iter()
            .filter_map(|cs_id| {
                preloaded_edges
                    .get(cs_id, should_apply_fallback)
                    .map(|edges| edges.map(|edges| (*cs_id, edges.into())))
                    .transpose()
            })
            .collect::<Result<_>>()?;

        let unfetched_ids: Vec<_> = cs_ids
            .iter()
            .filter(|cs_id| !fetched_edges.contains_key(cs_id))
            .copied()
            .collect();

        if !unfetched_ids.is_empty() {
            fetched_edges.extend(
                self.persistent_storage
                    .maybe_fetch_many_edges(ctx, unfetched_ids.as_slice(), prefetch)
                    .await?,
            )
        }

        Ok(fetched_edges)
    }

    async fn find_by_prefix(
        &self,
        ctx: &CoreContext,
        cs_prefix: ChangesetIdPrefix,
        limit: usize,
    ) -> Result<ChangesetIdsResolvedFromPrefix> {
        self.persistent_storage
            .find_by_prefix(ctx, cs_prefix, limit)
            .await
    }

    async fn fetch_children(&self, ctx: &CoreContext, cs: ChangesetId) -> Result<Vec<ChangesetId>> {
        self.persistent_storage.fetch_children(ctx, cs).await
    }
}
