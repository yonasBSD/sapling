/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use configmodel::Config;
use context::CoreContext;
use manifest_tree::ReadTreeManifest;
use manifest_tree::TreeManifest;
use parking_lot::Mutex;
use pathmatcher::DynMatcher;
use treestate::treestate::TreeState;
use types::HgId;
use vfs::VFS;

use crate::client::WorkingCopyClient;
use crate::filesystem::DotGitFileSystem;
use crate::filesystem::FileSystem;
use crate::filesystem::PendingChange;

pub struct GrepoFileSystem {
    inner: DotGitFileSystem,
}

impl GrepoFileSystem {
    pub fn new(
        inner: DotGitFileSystem,
        _vfs: VFS,
        _tree_resolver: Arc<dyn ReadTreeManifest>,
    ) -> Self {
        GrepoFileSystem { inner }
    }
}

impl FileSystem for GrepoFileSystem {
    fn pending_changes(
        &self,
        _context: &CoreContext,
        _matcher: DynMatcher,
        _ignore_matcher: DynMatcher,
        _ignore_dirs: Vec<PathBuf>,
        _include_ignored: bool,
    ) -> Result<Box<dyn Iterator<Item = Result<PendingChange>>>> {
        unimplemented!()
    }

    fn wait_for_potential_change(&self, config: &dyn Config) -> Result<()> {
        self.inner.wait_for_potential_change(config)
    }

    fn sparse_matcher(
        &self,
        manifests: &[Arc<TreeManifest>],
        dot_dir: &'static str,
    ) -> Result<Option<DynMatcher>> {
        self.inner.sparse_matcher(manifests, dot_dir)
    }

    fn set_parents(
        &self,
        p1: HgId,
        p2: Option<HgId>,
        parent_tree_hash: Option<HgId>,
    ) -> Result<()> {
        self.inner.set_parents(p1, p2, parent_tree_hash)
    }

    fn get_treestate(&self) -> Result<Arc<Mutex<TreeState>>> {
        self.inner.get_treestate()
    }

    fn get_client(&self) -> Option<Arc<dyn WorkingCopyClient>> {
        self.inner.get_client()
    }
}
