/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::BTreeMap;
use std::sync::Arc;

use anyhow::Result;
use blobstore::KeyedBlobstore;
use borrowed::borrowed;
use bounded_traversal::bounded_traversal;
use context::CoreContext;
use either::Either;
use futures::future::FutureExt;
use mononoke_types::ChangesetId;
use mononoke_types::MPathElement;
use mononoke_types::history_manifest::HistoryManifestDirectory;
use mononoke_types::history_manifest::HistoryManifestEntry;
use mononoke_types::prefix_tree::PrefixTree;
use mononoke_types::sharded_map_v2::LoadableShardedMapV2Node;
use smallvec::SmallVec;

/// Node for the merge_subtrees bounded_traversal.
///
/// Each node represents a position in the trie where we're comparing the
/// changed names against the parent sharded maps. The `prefix` tracks how
/// deep we are in the trie — it's a byte-level prefix within MPathElement
/// names, not a path component.
///
/// ## Example
///
/// A directory contains entries: `aa.txt`, `ab.txt`, `ba.txt`, `bb.txt`.
/// The changeset modifies `aa.txt`. The traversal proceeds:
///
/// ```text
/// prefix    changes                  parents (from sharded map)
/// []        PrefixTree{"aa.txt":()}  [{a: subtree, b: subtree}]
/// [a]       PrefixTree{"a.txt":()}   [{a.txt: entry, b.txt: entry}]
/// [b]       empty                    [{a.txt: entry, b.txt: entry}]  <- reused!
/// ```
///
/// At prefix `[b]`, `changes` is empty so the entire subtree is reused
/// without loading its contents. At prefix `[a]`, we descend further because
/// there are changes under that byte.
struct MergeSubtreesNode {
    /// Byte prefix within MPathElement names at this level of the trie.
    /// For example, if we're looking at entries starting with byte `a` (0x61)
    /// within a directory, this is `[0x61]`. Grows by one byte per level.
    prefix: SmallVec<[u8; 24]>,

    /// Trie of changed MPathElement names (from the bonsai changeset's
    /// PathTree children). Used to decide whether to descend into a subtree
    /// or short-circuit it as unchanged.
    changes: PrefixTree<()>,

    /// Parent sharded map nodes at this prefix, one per parent commit.
    /// These are expanded one byte at a time in lockstep with `changes`.
    parents: Vec<(ChangesetId, LoadableShardedMapV2Node<HistoryManifestEntry>)>,
}

/// Result of merge_subtrees.
pub(crate) struct MergeSubtreesResult {
    /// Unchanged entries where parents disagree on the value. Keyed by
    /// name, with the parent entries from each parent commit.
    pub(crate) disagreements: BTreeMap<MPathElement, Vec<(ChangesetId, HistoryManifestEntry)>>,

    /// Unchanged entries and subtrees where all parents agree. Each item
    /// is a byte prefix and either:
    /// - `Left(entry)`: a single entry whose full key equals the prefix.
    /// - `Right(node)`: an opaque sharded map subtree at the prefix.
    pub(crate) reused: Vec<(
        SmallVec<[u8; 24]>,
        Either<HistoryManifestEntry, LoadableShardedMapV2Node<HistoryManifestEntry>>,
    )>,

    /// Parent entries for changed names, encountered during the traversal.
    /// Keyed by name, with the parent entries from each parent commit.
    pub(crate) changed_parent_entries:
        BTreeMap<MPathElement, Vec<(ChangesetId, HistoryManifestEntry)>>,
}

/// Partition parent directory subentries into three groups based on a set
/// of changed names:
///
/// - **`reused`**: unchanged entries/subtrees where all parents agree.
/// - **`disagreements`**: unchanged entries where parents disagree.
/// - **`changed_parent_entries`**: parent entries for the changed names.
pub(crate) async fn merge_subtrees<'a>(
    ctx: &CoreContext,
    blobstore: &Arc<dyn KeyedBlobstore>,
    parent_dirs: &[(ChangesetId, HistoryManifestDirectory)],
    changed_names: impl Iterator<Item = &'a MPathElement>,
) -> Result<MergeSubtreesResult> {
    // Build a PrefixTree of changed MPathElement names. Each name's bytes
    // become a key in the trie, allowing byte-level lockstep expansion
    // against the parent sharded maps.
    let changes = changed_names.fold(PrefixTree::default(), |mut tree, name| {
        tree.insert(name.as_ref(), ());
        tree
    });

    // Wrap each parent directory's subentries as a LoadableShardedMapV2Node
    // so we can call expand() on them during the traversal.
    let parent_maps: Vec<(ChangesetId, LoadableShardedMapV2Node<HistoryManifestEntry>)> =
        parent_dirs
            .iter()
            .map(|(cs_id, dir)| {
                (
                    *cs_id,
                    LoadableShardedMapV2Node::Inlined(dir.subentries.clone()),
                )
            })
            .collect();

    let root_node = MergeSubtreesNode {
        prefix: SmallVec::new(),
        changes,
        parents: parent_maps,
    };

    borrowed!(ctx, blobstore);

    let result = bounded_traversal(
        256,
        root_node,
        // unfold: at each trie level, decide whether to reuse the subtree
        // or descend further.
        move |node: MergeSubtreesNode| {
            async move {
                let MergeSubtreesNode {
                    prefix,
                    changes,
                    parents,
                } = node;
                let blobstore: &Arc<dyn KeyedBlobstore> = blobstore;

                // No changes overlap with this subtree. If all parents agree
                // (or there's only one parent), reuse the parent's sharded
                // map node at this prefix without loading its contents.
                if changes.is_empty() {
                    let all_same = parents.windows(2).all(|w| w[0].1 == w[1].1);
                    if parents.len() <= 1 || all_same {
                        let reused = parents
                            .into_iter()
                            .next()
                            .map(|(_, map)| (prefix.clone(), Either::Right(map)));
                        return Ok((
                            MergeSubtreesResult {
                                disagreements: BTreeMap::new(),
                                reused: reused.into_iter().collect(),
                                changed_parent_entries: BTreeMap::new(),
                            },
                            vec![],
                        ));
                    }
                }

                // Expand the changes trie by one byte. `current_change` is
                // Some(()) if a changed name ends exactly at this prefix
                // (i.e. `prefix` is a complete MPathElement name).
                // `child_changes` contains sub-tries for each next byte.
                let (current_change, child_changes) = changes.expand();

                // Group child traversal nodes by next byte — each byte gets
                // a sub-trie of remaining changes and the corresponding
                // parent sharded map nodes.
                let mut child_nodes: BTreeMap<
                    u8,
                    (
                        PrefixTree<()>,
                        Vec<(ChangesetId, LoadableShardedMapV2Node<HistoryManifestEntry>)>,
                    ),
                > = BTreeMap::new();

                for (next_byte, child_change) in child_changes {
                    child_nodes
                        .entry(next_byte)
                        .or_insert_with(|| (PrefixTree::default(), Vec::new()))
                        .0 = child_change;
                }

                // Expand each parent's sharded map node by one byte.
                // `root_value` is the entry whose full key equals `prefix`
                // (if any). `child_maps` are the sub-nodes keyed by next byte.
                //
                // Example: expanding parent at prefix [e] might yield
                // root_value=None (no entry named exactly "e") and
                // child_maps=[(a, subtree_for_ea), (b, subtree_for_eb)].
                let mut current_parent_entries: Vec<(ChangesetId, HistoryManifestEntry)> =
                    Vec::new();

                for (parent_cs_id, parent_map) in parents {
                    let (root_value, child_maps) =
                        parent_map.expand(ctx, blobstore).await?;

                    if let Some(entry) = root_value {
                        current_parent_entries.push((parent_cs_id, entry));
                    }

                    for (next_byte, child_map) in child_maps {
                        child_nodes
                            .entry(next_byte)
                            .or_insert_with(|| (PrefixTree::default(), Vec::new()))
                            .1
                            .push((parent_cs_id, child_map));
                    }
                }

                let mut result = MergeSubtreesResult {
                    disagreements: BTreeMap::new(),
                    reused: Vec::new(),
                    changed_parent_entries: BTreeMap::new(),
                };

                // Handle entries whose full MPathElement name equals the
                // current prefix. These are leaf entries in the sharded map
                // trie (not to be confused with file/directory leaves).
                if !current_parent_entries.is_empty() {
                    let name = MPathElement::new_from_slice(&prefix)?;

                    if current_change.is_some() {
                        // Changed entry — record parent entries for the
                        // caller to attach to its UnfoldNode.
                        result
                            .changed_parent_entries
                            .insert(name, current_parent_entries);
                    } else {
                        // Unchanged entry. If all parents agree, reuse it.
                        // If they disagree, record the disagreement.
                        let all_same = current_parent_entries
                            .windows(2)
                            .all(|w| w[0].1 == w[1].1);

                        if all_same {
                            // All parents agree — reuse the entry directly.
                            let entry =
                                current_parent_entries.into_iter().next().unwrap().1;
                            result.reused.push((prefix.clone(), Either::Left(entry)));
                        } else {
                            // Parents disagree — return the raw parent
                            // entries so the caller can construct an
                            // UnfoldNode.
                            result
                                .disagreements
                                .insert(name, current_parent_entries);
                        }
                    }
                }

                // Build child traversal nodes — one per next byte that has
                // either changes or parent entries (or both).
                let children: Vec<MergeSubtreesNode> = child_nodes
                    .into_iter()
                    .map(|(next_byte, (child_changes, child_parents))| {
                        let mut child_prefix = prefix.clone();
                        child_prefix.push(next_byte);
                        MergeSubtreesNode {
                            prefix: child_prefix,
                            changes: child_changes,
                            parents: child_parents,
                        }
                    })
                    .collect();

                Ok((result, children))
            }
            .boxed()
        },
        // fold: accumulate reused entries and disagreements from all subtrees.
        |mut result: MergeSubtreesResult,
         child_results: std::iter::Flatten<
            std::vec::IntoIter<Option<MergeSubtreesResult>>,
        >| {
            async move {
                for child_result in child_results {
                    result.reused.extend(child_result.reused);
                    result
                        .disagreements
                        .extend(child_result.disagreements);
                    result
                        .changed_parent_entries
                        .extend(child_result.changed_parent_entries);
                }
                anyhow::Ok(result)
            }
            .boxed()
        },
    )
    .await?;

    Ok(MergeSubtreesResult {
        disagreements: result.disagreements,
        reused: result.reused,
        changed_parent_entries: result.changed_parent_entries,
    })
}
