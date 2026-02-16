/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;

use mononoke_app::MononokeReposManager;

use crate::repo::Repo;

pub struct MultiRepoLandServiceImpl {
    #[allow(dead_code)]
    pub(crate) repos_mgr: Arc<MononokeReposManager<Repo>>,
}

impl MultiRepoLandServiceImpl {
    pub fn new(repos_mgr: Arc<MononokeReposManager<Repo>>) -> Self {
        Self { repos_mgr }
    }
}
