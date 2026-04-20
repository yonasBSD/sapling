/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::collections::BTreeMap;
use std::collections::HashMap;

use anyhow::Result;
use anyhow::bail;
use flume::Receiver;
use flume::Sender;
use flume::WeakSender;
use minibytes::Bytes;
use types::FetchContext;
use types::HgId;
use types::Key;
use types::PathComponentBuf;
use types::RepoPath;

use crate::link::DurableEntry;
use crate::link::Link;
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

/// Batch-fetch tree content. Errors are silently ignored — they'll be retried
/// in `materialize_links`.
pub(crate) fn prefetch_trees(store: &InnerStore, keys: Vec<Key>) -> HashMap<HgId, Bytes> {
    let span = tracing::debug_span!(
        "tree::store::prefetch",
        ids = keys
            .iter()
            .map(|k| k.hgid.to_hex())
            .collect::<Vec<String>>()
            .join(" ")
    );
    let _entered = span.enter();

    store
        .get_content_iter(FetchContext::default(), keys)
        .ok()
        .map(|iter| {
            iter.filter_map(|r| r.ok())
                .map(|(key, blob)| (key.hgid, blob.into_bytes()))
                .collect()
        })
        .unwrap_or_default()
}

pub(crate) fn materialize_links<'a>(
    entry: &'a DurableEntry,
    store: &InnerStore,
    path: &RepoPath,
    prefetched: &HashMap<HgId, Bytes>,
) -> Result<&'a BTreeMap<PathComponentBuf, Link>> {
    let data = prefetched.get(&entry.hgid);
    entry.materialize_links(store, path, data)
}
