/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use context::CoreContext;
use multi_repo_land_if::MultipleRepoModifyBookmarksParams;
use multi_repo_land_if::MultipleRepoModifyBookmarksResponse;

use crate::service::MultiRepoLandServiceImpl;

impl MultiRepoLandServiceImpl {
    pub async fn multiple_repo_modify_bookmarks(
        &self,
        _ctx: CoreContext,
        _params: MultipleRepoModifyBookmarksParams,
    ) -> Result<MultipleRepoModifyBookmarksResponse> {
        unimplemented!("multiple_repo_modify_bookmarks will be implemented in a subsequent diff")
    }
}
