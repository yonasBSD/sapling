/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;

use anyhow::anyhow;
use async_trait::async_trait;
use context::CoreContext;
use context::SessionContainer;
use fbinit::FacebookInit;
use metadata::Metadata;
use mononoke_app::MononokeReposManager;
use multi_repo_land_if_services::MultiRepoLandService;
use multi_repo_land_if_services::errors::MultipleRepoModifyBookmarksExn;
use multi_repo_land_if_services::errors::RepoFetchManifestContentExn;
use permission_checker::MononokeIdentity;
use permission_checker::MononokeIdentitySet;
use scuba_ext::MononokeScubaSampleBuilder;
use source_control as thrift;
use srserver::RequestContext;

use crate::repo::Repo;

pub struct MultiRepoLandServiceImpl {
    pub(crate) fb: FacebookInit,
    pub(crate) repos_mgr: Arc<MononokeReposManager<Repo>>,
}

impl MultiRepoLandServiceImpl {
    pub fn new(fb: FacebookInit, repos_mgr: Arc<MononokeReposManager<Repo>>) -> Self {
        Self { fb, repos_mgr }
    }

    /// Create a CoreContext from the Thrift RequestContext.
    async fn create_ctx(
        &self,
        _method: &str,
        req_ctxt: &RequestContext,
    ) -> anyhow::Result<CoreContext> {
        let identities: MononokeIdentitySet = req_ctxt
            .identities()
            .map_err(|e| anyhow!("failed to get identities: {}", e))?
            .entries()
            .into_iter()
            .map(MononokeIdentity::from_identity_ref)
            .collect();

        let metadata = Metadata::new(
            None,
            identities,
            false,
            metadata::security::is_client_untrusted(|h| Ok(req_ctxt.header(h).ok().flatten()))?,
            None, // client_ip
            None, // client_port
        )
        .await;

        let session = SessionContainer::builder(self.fb)
            .metadata(Arc::new(metadata))
            .build();

        let scuba = MononokeScubaSampleBuilder::with_discard();
        Ok(session.new_context(scuba))
    }
}

#[async_trait]
impl MultiRepoLandService for MultiRepoLandServiceImpl {
    type RequestContext = RequestContext;

    async fn repo_fetch_manifest_content(
        &self,
        req_ctxt: &RequestContext,
        params: multi_repo_land_if::RepoFetchManifestContentParams,
    ) -> Result<multi_repo_land_if::RepoFetchManifestContentResponse, RepoFetchManifestContentExn>
    {
        let ctx = self
            .create_ctx("repo_fetch_manifest_content", req_ctxt)
            .await
            .map_err(|e| {
                RepoFetchManifestContentExn::internal_error(thrift::InternalError {
                    reason: format!("{:#}", e),
                    ..Default::default()
                })
            })?;

        self.repo_fetch_manifest_content(ctx, params)
            .await
            .map_err(|e| {
                RepoFetchManifestContentExn::internal_error(thrift::InternalError {
                    reason: format!("{:#}", e),
                    ..Default::default()
                })
            })
    }

    async fn multiple_repo_modify_bookmarks(
        &self,
        req_ctxt: &RequestContext,
        params: multi_repo_land_if::MultipleRepoModifyBookmarksParams,
    ) -> Result<
        multi_repo_land_if::MultipleRepoModifyBookmarksResponse,
        MultipleRepoModifyBookmarksExn,
    > {
        let ctx = self
            .create_ctx("multiple_repo_modify_bookmarks", req_ctxt)
            .await
            .map_err(|e| {
                MultipleRepoModifyBookmarksExn::internal_error(thrift::InternalError {
                    reason: format!("{:#}", e),
                    ..Default::default()
                })
            })?;

        match self.multiple_repo_modify_bookmarks(ctx, params).await {
            Ok(resp) => Ok(resp),
            Err(e) => {
                // Check if the error is a structured Thrift exception that
                // should be returned as-is rather than wrapped as InternalError.
                if let Some(cas_failure) =
                    e.downcast_ref::<multi_repo_land_if::MultiRepoLandCasFailure>()
                {
                    return Err(MultipleRepoModifyBookmarksExn::cas_failure(
                        cas_failure.clone(),
                    ));
                }
                if let Some(rebase_conflict) =
                    e.downcast_ref::<multi_repo_land_if::MultiRepoLandRebaseConflict>()
                {
                    return Err(MultipleRepoModifyBookmarksExn::rebase_conflict(
                        rebase_conflict.clone(),
                    ));
                }

                Err(MultipleRepoModifyBookmarksExn::internal_error(
                    thrift::InternalError {
                        reason: format!("{:#}", e),
                        ..Default::default()
                    },
                ))
            }
        }
    }
}
