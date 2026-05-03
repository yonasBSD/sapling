/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::collections::BTreeMap;
use std::collections::HashMap;
use std::sync::Arc;

use anyhow::Result;
use anyhow::bail;
use edenapi_types::SaplingRemoteApiServerErrorKind;
use edenapi_types::errors::find_permission_denied;
use edenapi_types::errors::is_permission_denied;
use flume::Receiver;
use flume::Sender;
use flume::WeakSender;
use manifest::FileMetadata;
use storemodel::TreeEntry;
use types::FetchContext;
use types::HgId;
use types::Key;
use types::PathComponentBuf;
use types::RepoPathBuf;

use crate::acl_metrics;
use crate::link::DurableEntry;
use crate::link::Link;
use crate::link::MaybeLinks;
use crate::store;
use crate::store::InnerStore;

fn num_workers() -> usize {
    num_cpus::get().min(20)
}

pub(crate) struct BfsWork<W, Ctx> {
    pub work: Vec<W>,
    pub ctx: Ctx,
}

pub(crate) trait Cancelable {
    fn canceled(&self) -> bool;
}

/// Returns false if the walk has been canceled.
pub(crate) fn try_send<W: Send + Sync + 'static, Ctx: Cancelable + Send + Sync + 'static>(
    work_send: &WeakSender<BfsWork<W, Ctx>>,
    work: BfsWork<W, Ctx>,
) -> Result<bool> {
    if work.ctx.canceled() {
        return Ok(false);
    }

    if work.work.is_empty() {
        return Ok(true);
    }

    match work_send.upgrade() {
        Some(send) => send.send(work)?,
        None => bail!("work channel disconnected (sender)"),
    }

    Ok(true)
}

/// Spawn BFS workers as dedicated threads with weak-sender shutdown.
/// Workers shut down when the returned strong `Sender` is dropped.
pub(crate) fn spawn_workers<W, Ctx, F>(worker_fn: F) -> Sender<BfsWork<W, Ctx>>
where
    W: Send + 'static,
    Ctx: Send + 'static,
    F: Fn(Receiver<BfsWork<W, Ctx>>, WeakSender<BfsWork<W, Ctx>>) -> Result<()>
        + Send
        + Clone
        + 'static,
{
    let (work_send, work_recv) = flume::unbounded();

    for _ in 0..num_workers() {
        let work_recv = work_recv.clone();
        let work_send_weak = work_send.downgrade();
        let worker_fn = worker_fn.clone();
        std::thread::spawn(move || {
            let res = worker_fn(work_recv, work_send_weak);
            tracing::debug!(?res, "bfs worker exited");
        });
    }

    work_send
}

fn tree_entry_to_links(
    parent_path: &types::RepoPath,
    entry: Arc<dyn TreeEntry>,
    denied_hgids: &HashMap<HgId, String>,
) -> Result<BTreeMap<PathComponentBuf, Link>> {
    let mut links = BTreeMap::new();
    for item in entry.iter_owned()? {
        let (component, hgid, flag) = item?;
        let link = match flag {
            store::Flag::File(file_type) => Link::leaf(FileMetadata::new(hgid, file_type)),
            store::Flag::Directory => {
                if let Some(request_acl) = denied_hgids.get(&hgid) {
                    let mut path = parent_path.to_owned();
                    path.push(component.as_path_component());
                    Link::durable_permission_denied(types::errors::PermissionDenied {
                        path,
                        hgid,
                        request_acl: request_acl.clone(),
                    })
                } else {
                    Link::durable(hgid)
                }
            }
        };
        links.insert(component, link);
    }
    Ok(links)
}

/// Batch-fetch tree content and populate DurableEntry links.
pub(crate) fn prefetch_trees<'a>(
    store: &InnerStore,
    entries: impl IntoIterator<Item = &'a Arc<DurableEntry>>,
) -> Result<()> {
    let mut by_hgid: HashMap<HgId, Vec<&'a Arc<DurableEntry>>> = HashMap::new();
    let mut keys = Vec::new();
    for entry in entries {
        if !entry.links_initialized() {
            let v = by_hgid.entry(entry.hgid).or_default();
            if v.is_empty() {
                keys.push(Key::new(RepoPathBuf::new(), entry.hgid));
            }
            v.push(entry);
        }
    }

    if keys.is_empty() {
        return Ok(());
    }

    let span = tracing::debug_span!(
        "tree::store::prefetch",
        ids = keys
            .iter()
            .map(|k| k.hgid.to_hex())
            .collect::<Vec<String>>()
            .join(" ")
    );
    let _entered = span.enter();

    for res in store.get_tree_iter(FetchContext::default(), keys)? {
        match res {
            Ok((key, tree_entry)) => {
                let mut denied_hgids = HashMap::new();
                match tree_entry.permission_denied_children() {
                    Ok(iter) => {
                        for item in iter {
                            match item {
                                Ok((_component, hgid, reason)) => {
                                    tracing::debug!(%hgid, reason, "marking child tree as permission denied");
                                    acl_metrics::ACL_AVOIDED.increment();
                                    denied_hgids.insert(hgid, reason);
                                }
                                Err(err) => {
                                    tracing::debug!(
                                        ?err,
                                        "error reading permission_denied_children"
                                    );
                                }
                            }
                        }
                    }
                    Err(err) => {
                        tracing::debug!(?err, "error calling permission_denied_children");
                    }
                }

                let links = tree_entry_to_links(&key.path, tree_entry, &denied_hgids)?;
                if let Some(entries) = by_hgid.get(&key.hgid) {
                    for entry in entries {
                        entry.links.get_or_init(|| MaybeLinks::Links(links.clone()));
                    }
                }
            }
            Err(ref err) if is_permission_denied(err) => {
                if let Some(SaplingRemoteApiServerErrorKind::PermissionDenied {
                    tree_id,
                    request_acl,
                }) = find_permission_denied(err).map(|e| &e.err)
                {
                    acl_metrics::ACL_DENIED.increment();
                    if let Some(entries) = by_hgid.get(tree_id) {
                        let perm_err = types::errors::PermissionDenied {
                            path: types::RepoPathBuf::new(),
                            hgid: *tree_id,
                            request_acl: request_acl.clone(),
                        };
                        for entry in entries {
                            entry
                                .links
                                .get_or_init(|| MaybeLinks::PermissionDenied(perm_err.clone()));
                        }
                    }
                }
            }
            Err(err) => return Err(err),
        }
    }
    Ok(())
}
