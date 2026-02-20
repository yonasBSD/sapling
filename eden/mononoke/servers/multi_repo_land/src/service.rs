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
use futures_ext::future::FbFutureExt;
use futures_stats::FutureStats;
use futures_stats::TimedFutureExt;
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
use stats::prelude::*;
use time_ext::DurationExt;

use crate::methods::multi_repo_modify::CasFailureWithMergeInfo;
use crate::methods::multi_repo_modify::RebaseConflictWithMergeInfo;
use crate::repo::Repo;

define_stats! {
    prefix = "mononoke.multi_repo_land";
    total_request_start: timeseries(Rate, Sum),
    total_request_success: timeseries(Rate, Sum),
    total_request_internal_failure: timeseries(Rate, Sum),
    total_request_canceled: timeseries(Rate, Sum),
    total_request_cas_failure: timeseries(Rate, Sum),
    total_request_rebase_conflict: timeseries(Rate, Sum),
    method_completion_time_ms: dynamic_histogram(
        "method.{}.completion_time_ms", (method: String);
        10, 0, 1_000, Average, Sum, Count; P 5; P 50; P 90),
}

pub struct MultiRepoLandServiceImpl {
    pub(crate) fb: FacebookInit,
    pub(crate) repos_mgr: Arc<MononokeReposManager<Repo>>,
    scuba_builder: MononokeScubaSampleBuilder,
}

impl MultiRepoLandServiceImpl {
    pub fn new(
        fb: FacebookInit,
        repos_mgr: Arc<MononokeReposManager<Repo>>,
        mut scuba_builder: MononokeScubaSampleBuilder,
    ) -> Self {
        scuba_builder.add_common_server_data();
        Self {
            fb,
            repos_mgr,
            scuba_builder,
        }
    }

    fn create_scuba(
        &self,
        method: &str,
        req_ctxt: &RequestContext,
    ) -> anyhow::Result<MononokeScubaSampleBuilder> {
        let mut scuba = self.scuba_builder.clone().with_seq("seq");
        scuba.add("type", "thrift");
        scuba.add("method", method);
        const CLIENT_HEADERS: &[&str] = &[
            "client_id",
            "client_type",
            "client_correlator",
            "proxy_client_id",
        ];
        for &header in CLIENT_HEADERS.iter() {
            if let Ok(Some(value)) = req_ctxt.header(header) {
                scuba.add(header, value);
            }
        }
        Ok(scuba)
    }

    /// Create a CoreContext from the Thrift RequestContext.
    async fn create_ctx(
        &self,
        method: &str,
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

        let scuba = self.create_scuba(method, req_ctxt)?;
        Ok(session.new_context(scuba))
    }
}

fn log_result(
    ctx: &CoreContext,
    method: &str,
    stats: &FutureStats,
    status: &str,
    error: Option<&str>,
    extra: impl FnOnce(&mut MononokeScubaSampleBuilder),
) {
    let mut scuba = ctx.scuba().clone();
    ctx.perf_counters().insert_perf_counters(&mut scuba);
    scuba.add_future_stats(stats);
    scuba.add("status", status);
    if let Some(err) = error {
        scuba.add("error", err.to_string());
    }
    extra(&mut scuba);
    STATS::method_completion_time_ms.add_value(
        stats.completion_time.as_millis_unchecked() as i64,
        (method.to_string(),),
    );
    scuba.log_with_msg("Request complete", None);
}

fn log_canceled(ctx: &CoreContext, method: &str, stats: &FutureStats) {
    STATS::total_request_canceled.add_value(1);
    let mut scuba = ctx.scuba().clone();
    ctx.perf_counters().insert_perf_counters(&mut scuba);
    scuba.add_future_stats(stats);
    scuba.add("status", "CANCELLED");
    STATS::method_completion_time_ms.add_value(
        stats.completion_time.as_millis_unchecked() as i64,
        (method.to_string(),),
    );
    scuba.log_with_msg("Request cancelled", None);
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

        {
            let mut scuba = ctx.scuba().clone();
            scuba.add("repo_name", params.repo.name.as_str());
            scuba.add("bookmark", params.bookmark.as_str());
            scuba.add("path", params.path.as_str());
            scuba.log_with_msg("Request start", None);
        }
        STATS::total_request_start.add_value(1);

        let method = "repo_fetch_manifest_content";
        let (stats, result) = self
            .repo_fetch_manifest_content(ctx.clone(), params)
            .timed()
            .on_cancel_with_data(|stats| log_canceled(&ctx, method, &stats))
            .await;

        match &result {
            Ok(response) => {
                STATS::total_request_success.add_value(1);
                let content_size = response.manifest_content.len();
                log_result(&ctx, method, &stats, "SUCCESS", None, |scuba| {
                    scuba.add("content_size", content_size);
                });
            }
            Err(e) => {
                STATS::total_request_internal_failure.add_value(1);
                log_result(
                    &ctx,
                    method,
                    &stats,
                    "INTERNAL_ERROR",
                    Some(&format!("{:#}", e)),
                    |_| {},
                );
            }
        }

        result.map_err(|e| {
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

        // Log method-specific params to scuba before starting
        {
            let mut scuba = ctx.scuba().clone();
            scuba.add(
                "num_repo_modifications",
                params.repo_bookmark_modifications.len(),
            );
            scuba.add(
                "num_manifest_modifications",
                params.manifest_bookmark_modifications.len(),
            );
            let repo_names: Vec<&str> = params
                .repo_bookmark_modifications
                .iter()
                .map(|m| m.repo.name.as_str())
                .collect();
            scuba.add("repo_names", repo_names.join(","));
            scuba.add("has_service_identity", params.service_identity.is_some());
            scuba.log_with_msg("Request start", None);
        }
        STATS::total_request_start.add_value(1);

        let method = "multiple_repo_modify_bookmarks";
        let (stats, result) = self
            .multiple_repo_modify_bookmarks(ctx.clone(), params)
            .timed()
            .on_cancel_with_data(|stats| log_canceled(&ctx, method, &stats))
            .await;

        match &result {
            Ok(_) => {
                STATS::total_request_success.add_value(1);
                log_result(&ctx, method, &stats, "SUCCESS", None, |_| {});
                Ok(result.unwrap())
            }
            Err(e) => {
                if let Some(cas_with_merge) = e.downcast_ref::<CasFailureWithMergeInfo>() {
                    STATS::total_request_cas_failure.add_value(1);
                    log_result(
                        &ctx,
                        method,
                        &stats,
                        "CAS_FAILURE",
                        Some(&cas_with_merge.cas_failure.message),
                        |scuba| {
                            let mi = &cas_with_merge.merge_info;
                            scuba.add("merge_attempted", mi.merge_attempted);
                            scuba.add("merge_succeeded", mi.merge_succeeded);
                            scuba.add("merge_files_count", mi.merge_files_count);
                            if let Some(ref file) = mi.merge_conflict_file {
                                scuba.add("merge_conflict_file", file.as_str());
                            }
                        },
                    );
                    return Err(MultipleRepoModifyBookmarksExn::cas_failure(
                        cas_with_merge.cas_failure.clone(),
                    ));
                }
                if let Some(conflict_with_merge) = e.downcast_ref::<RebaseConflictWithMergeInfo>() {
                    STATS::total_request_rebase_conflict.add_value(1);
                    log_result(
                        &ctx,
                        method,
                        &stats,
                        "REBASE_CONFLICT",
                        Some(&conflict_with_merge.rebase_conflict.message),
                        |scuba| {
                            let mi = &conflict_with_merge.merge_info;
                            scuba.add("merge_attempted", mi.merge_attempted);
                            scuba.add("merge_succeeded", mi.merge_succeeded);
                            scuba.add("merge_files_count", mi.merge_files_count);
                            if let Some(ref file) = mi.merge_conflict_file {
                                scuba.add("merge_conflict_file", file.as_str());
                            }
                        },
                    );
                    return Err(MultipleRepoModifyBookmarksExn::rebase_conflict(
                        conflict_with_merge.rebase_conflict.clone(),
                    ));
                }

                STATS::total_request_internal_failure.add_value(1);
                let err_str = format!("{:#}", e);
                log_result(
                    &ctx,
                    method,
                    &stats,
                    "INTERNAL_ERROR",
                    Some(&err_str),
                    |_| {},
                );
                Err(MultipleRepoModifyBookmarksExn::internal_error(
                    thrift::InternalError {
                        reason: err_str,
                        ..Default::default()
                    },
                ))
            }
        }
    }
}
