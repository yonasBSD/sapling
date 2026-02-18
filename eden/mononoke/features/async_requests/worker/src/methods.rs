/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! The concrete method implementations.
//!
//! This module provides the concrete implementations for methods - functions
//! taking the Params and returning the Results - to be used by the request worker.
//! This module is not aware of the async nature of those methods. All the token
//! handling, enqueuing and polling should be done by the callers.

use std::collections::HashMap;
use std::num::NonZeroU32;
use std::num::NonZeroUsize;
use std::sync::Arc;
use std::sync::atomic::AtomicUsize;
use std::sync::atomic::Ordering;

use anyhow::Error;
use anyhow::Result;
use anyhow::bail;
use async_requests::AsyncRequestsError;
use async_requests::types::AsynchronousRequestParams;
use async_requests::types::AsynchronousRequestResult;
use async_requests::types::IntoConfigFormat;
use bulk_derivation::BulkDerivation;
use context::CoreContext;
use derived_data_manager::DerivedDataManager;
use ephemeral_blobstore::BubbleId;
use ephemeral_blobstore::RepoEphemeralStore;
use futures::Future;
use futures::FutureExt;
use futures::StreamExt;
use futures::TryStreamExt;
use futures::future::BoxFuture;
use futures::stream;
use futures::try_join;
use futures_watchdog::WatchdogExt;
use megarepo_api::MegarepoApi;
use megarepo_error::MegarepoError;
use mononoke_api::ChangesetContext;
use mononoke_api::ChangesetSpecifier;
use mononoke_api::Mononoke;
use mononoke_api::MononokeRepo;
use mononoke_api::Repo;
use mononoke_api::RepoContext;
use mononoke_types::ChangesetId;
use mononoke_types::DerivableType;
use mononoke_types::RepositoryId;
use repo_authorization::AuthorizationContext;
use repo_blobstore::RepoBlobstore;
use repo_derived_data::RepoDerivedDataRef;
use scs_errors::ServiceErrorResultExt;
#[cfg(fbcode_build)]
use scs_methods::commit_sparse_profile_info::commit_sparse_profile_delta_impl;
#[cfg(fbcode_build)]
use scs_methods::commit_sparse_profile_info::commit_sparse_profile_size_impl;
use scs_methods::from_request::FromRequest;
use scs_methods::specifiers::SpecifierExt;
use source_control as thrift;
use source_control::CommitSpecifier;
use throttledblob::ThrottleOptions;
use throttledblob::ThrottledBlob;
use tracing::info;

const METHOD_MAX_POLL_TIME_MS: u64 = 100;

/// JustKnob for write QPS throttling during backfill derivation
const JK_BACKFILL_WRITE_QPS: &str = "scm/mononoke:derived_data_backfill_write_qps";
/// JustKnob for write bytes/s throttling during backfill derivation
const JK_BACKFILL_WRITE_BYTES_S: &str = "scm/mononoke:derived_data_backfill_write_bytes_s";
/// JustKnob for read QPS throttling during backfill derivation
const JK_BACKFILL_READ_QPS: &str = "scm/mononoke:derived_data_backfill_read_qps";
/// JustKnob for read bytes/s throttling during backfill derivation
const JK_BACKFILL_READ_BYTES_S: &str = "scm/mononoke:derived_data_backfill_read_bytes_s";

/// Get a DerivedDataManager with optional read/write throttling applied.
/// If JustKnobs are not set or are zero, returns the manager unchanged.
fn get_throttled_manager(manager: &DerivedDataManager) -> Result<DerivedDataManager> {
    let write_qps = justknobs::get_as::<i64>(JK_BACKFILL_WRITE_QPS, None)?;
    let write_bytes = justknobs::get_as::<i64>(JK_BACKFILL_WRITE_BYTES_S, None)?;
    let read_qps = justknobs::get_as::<i64>(JK_BACKFILL_READ_QPS, None)?;
    let read_bytes = justknobs::get_as::<i64>(JK_BACKFILL_READ_BYTES_S, None)?;

    if write_qps <= 0 && write_bytes <= 0 && read_qps <= 0 && read_bytes <= 0 {
        return Ok(manager.clone());
    }

    let options = ThrottleOptions {
        write_qps: NonZeroU32::new(write_qps.max(0) as u32),
        write_bytes: NonZeroUsize::new(write_bytes.max(0) as usize),
        read_qps: NonZeroU32::new(read_qps.max(0) as u32),
        read_bytes: NonZeroUsize::new(read_bytes.max(0) as usize),
        ..Default::default()
    };

    info!(
        "Applying throttle: write_qps={:?}, write_bytes/s={:?}, read_qps={:?}, read_bytes/s={:?}",
        options.write_qps, options.write_bytes, options.read_qps, options.read_bytes,
    );

    let repo_blobstore = manager.repo_blobstore().clone();
    let throttled_blobstore =
        RepoBlobstore::new_with_wrapped_inner_blobstore(repo_blobstore, |inner| {
            Arc::new(ThrottledBlob::new(inner, options))
        });
    Ok(manager.with_replaced_blobstore(throttled_blobstore))
}

#[cfg(not(fbcode_build))]
pub async fn commit_sparse_profile_delta_impl(
    ctx: &CoreContext,
    repo: RepoContext<Repo>,
    changeset: ChangesetContext<Repo>,
    other: ChangesetContext<Repo>,
    profiles: thrift::SparseProfiles,
) -> Result<thrift::CommitSparseProfileDeltaResponse, scs_errors::ServiceError> {
    Err(scs_errors::ServiceError::Request(
        scs_errors::not_implemented("not implemented in non-fbcode build".to_string()),
    ))
}

#[cfg(not(fbcode_build))]
pub async fn commit_sparse_profile_size_impl(
    ctx: &CoreContext,
    repo: RepoContext<Repo>,
    changeset: ChangesetContext<Repo>,
    profiles: thrift::SparseProfiles,
) -> Result<thrift::CommitSparseProfileSizeResponse, scs_errors::ServiceError> {
    Err(scs_errors::ServiceError::Request(
        scs_errors::not_implemented("not implemented in non-fbcode build".to_string()),
    ))
}

async fn megarepo_sync_changeset<R: MononokeRepo>(
    ctx: &CoreContext,
    megarepo_api: &MegarepoApi<R>,
    params: thrift::MegarepoSyncChangesetParams,
) -> Result<thrift::MegarepoSyncChangesetResponse, MegarepoError> {
    let source_cs_id = ChangesetId::from_bytes(params.cs_id).map_err(MegarepoError::request)?;
    let target_location =
        ChangesetId::from_bytes(params.target_location).map_err(MegarepoError::request)?;
    let cs_id = megarepo_api
        .sync_changeset(
            ctx,
            source_cs_id,
            params.source_name,
            params.target.into_config_format(&megarepo_api.mononoke())?,
            target_location,
        )
        .watched()
        .await?
        .as_ref()
        .into();
    Ok(thrift::MegarepoSyncChangesetResponse {
        cs_id,
        ..Default::default()
    })
}

async fn megarepo_add_sync_target<R: MononokeRepo>(
    ctx: &CoreContext,
    megarepo_api: &MegarepoApi<R>,
    params: thrift::MegarepoAddTargetParams,
) -> Result<thrift::MegarepoAddTargetResponse, MegarepoError> {
    let config = params.config_with_new_target;
    let mut changesets_to_merge = HashMap::new();
    for (s, cs_id) in params.changesets_to_merge {
        let cs_id = ChangesetId::from_bytes(cs_id).map_err(MegarepoError::request)?;
        changesets_to_merge.insert(s, cs_id);
    }
    let cs_id = megarepo_api
        .add_sync_target(
            ctx,
            config.into_config_format(&megarepo_api.mononoke())?,
            changesets_to_merge,
            params.message,
        )
        .await?
        .as_ref()
        .into();
    Ok(thrift::MegarepoAddTargetResponse {
        cs_id,
        ..Default::default()
    })
}

async fn megarepo_add_branching_sync_target<R: MononokeRepo>(
    ctx: &CoreContext,
    megarepo_api: &MegarepoApi<R>,
    params: thrift::MegarepoAddBranchingTargetParams,
) -> Result<thrift::MegarepoAddBranchingTargetResponse, MegarepoError> {
    let cs_id = megarepo_api
        .add_branching_sync_target(
            ctx,
            params.target.into_config_format(&megarepo_api.mononoke())?,
            ChangesetId::from_bytes(params.branching_point).map_err(MegarepoError::request)?,
            params
                .source_target
                .into_config_format(&megarepo_api.mononoke())?,
        )
        .await?
        .as_ref()
        .into();
    Ok(thrift::MegarepoAddBranchingTargetResponse {
        cs_id,
        ..Default::default()
    })
}

async fn megarepo_change_target_config<R: MononokeRepo>(
    ctx: &CoreContext,
    megarepo_api: &MegarepoApi<R>,
    params: thrift::MegarepoChangeTargetConfigParams,
) -> Result<thrift::MegarepoChangeTargetConfigResponse, MegarepoError> {
    let mut changesets_to_merge = HashMap::new();
    for (s, cs_id) in params.changesets_to_merge {
        let cs_id = ChangesetId::from_bytes(cs_id).map_err(MegarepoError::request)?;
        changesets_to_merge.insert(s, cs_id);
    }
    let target_location =
        ChangesetId::from_bytes(params.target_location).map_err(MegarepoError::request)?;
    let cs_id = megarepo_api
        .change_target_config(
            ctx,
            params.target.into_config_format(&megarepo_api.mononoke())?,
            params.new_version,
            target_location,
            changesets_to_merge,
            params.message,
        )
        .await?
        .as_ref()
        .into();
    Ok(thrift::MegarepoChangeTargetConfigResponse {
        cs_id,
        ..Default::default()
    })
}

async fn megarepo_remerge_source<R: MononokeRepo>(
    ctx: &CoreContext,
    megarepo_api: &MegarepoApi<R>,
    params: thrift::MegarepoRemergeSourceParams,
) -> Result<thrift::MegarepoRemergeSourceResponse, MegarepoError> {
    let remerge_cs_id = ChangesetId::from_bytes(params.cs_id).map_err(MegarepoError::request)?;
    let target_location =
        ChangesetId::from_bytes(params.target_location).map_err(MegarepoError::request)?;
    let cs_id = megarepo_api
        .remerge_source(
            ctx,
            params.source_name,
            remerge_cs_id,
            params.message,
            &params.target.into_config_format(&megarepo_api.mononoke())?,
            target_location,
        )
        .await?
        .as_ref()
        .into();

    Ok(thrift::MegarepoRemergeSourceResponse {
        cs_id,
        ..Default::default()
    })
}

pub async fn commit_sparse_profile_size(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    params: thrift::CommitSparseProfileSizeParamsV2,
) -> Result<thrift::CommitSparseProfileSizeResponse, AsyncRequestsError> {
    let (repo, changeset) = get_repo_and_changeset(ctx, mononoke, &params.commit)
        .await
        .map_err(<scs_errors::ServiceError as Into<AsyncRequestsError>>::into)?;

    commit_sparse_profile_size_impl(ctx, repo, changeset, params.profiles)
        .await
        .map_err(<scs_errors::ServiceError as Into<AsyncRequestsError>>::into)
}

pub async fn commit_sparse_profile_delta(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    params: thrift::CommitSparseProfileDeltaParamsV2,
) -> Result<thrift::CommitSparseProfileDeltaResponse, AsyncRequestsError> {
    let (repo, changeset, other) =
        repo_changeset_pair(ctx.clone(), mononoke, &params.commit, &params.other_id)
            .await
            .map_err(<scs_errors::ServiceError as Into<AsyncRequestsError>>::into)?;

    commit_sparse_profile_delta_impl(ctx, repo, changeset, other, params.profiles)
        .await
        .map_err(<scs_errors::ServiceError as Into<AsyncRequestsError>>::into)
}

/// Compute derive_boundaries request - derives boundary changesets using predecessor derivation
async fn compute_derive_boundaries(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    params: thrift::DeriveBoundariesParams,
) -> Result<thrift::DeriveBoundariesResponse, AsyncRequestsError> {
    let repo_id = RepositoryId::new(
        params
            .repo_id
            .try_into()
            .map_err(|e| AsyncRequestsError::request(anyhow::anyhow!("Invalid repo_id: {}", e)))?,
    );

    let repo = mononoke
        .repo_by_id(ctx.clone(), repo_id)
        .await
        .map_err(AsyncRequestsError::internal)?
        .ok_or_else(|| {
            AsyncRequestsError::request(anyhow::anyhow!("Repo not found: {}", params.repo_id))
        })?
        .with_authorization_context(AuthorizationContext::new_bypass_access_control())
        .build()
        .await
        .map_err(AsyncRequestsError::internal)?;

    let derived_data_type =
        DerivableType::from_name(&params.derived_data_type).map_err(AsyncRequestsError::request)?;

    let boundary_cs_ids: Vec<ChangesetId> = params
        .boundary_cs_ids
        .iter()
        .map(ChangesetId::from_bytes)
        .collect::<Result<Vec<_>, _>>()
        .map_err(AsyncRequestsError::request)?;

    info!(
        "Deriving {} boundary changesets for repo {} type {:?}",
        boundary_cs_ids.len(),
        params.repo_id,
        derived_data_type,
    );

    let derived_count = Arc::new(AtomicUsize::new(0));
    let manager = get_throttled_manager(repo.repo().repo_derived_data().manager())
        .map_err(AsyncRequestsError::internal)?;
    let concurrency = params.concurrency.max(1) as usize;
    let use_predecessor = params.use_predecessor_derivation;

    stream::iter(boundary_cs_ids)
        .map(Ok::<_, Error>)
        .try_for_each_concurrent(concurrency, |csid| {
            let manager = manager.clone();
            let ctx = ctx.clone();
            let derived_count = derived_count.clone();
            async move {
                if use_predecessor {
                    BulkDerivation::unsafe_derive_untopologically(
                        &manager,
                        &ctx,
                        csid,
                        None, // rederivation
                        derived_data_type,
                    )
                    .await?;
                } else {
                    manager
                        .derive_bulk_locally(
                            &ctx,
                            &[csid],
                            None, // rederivation
                            &[derived_data_type],
                            None, // override_batch_size
                        )
                        .await
                        .map_err(|e| anyhow::anyhow!("{}", e))?;
                }
                derived_count.fetch_add(1, Ordering::SeqCst);
                Ok::<_, Error>(())
            }
        })
        .await
        .map_err(AsyncRequestsError::internal)?;

    let count = derived_count.load(Ordering::SeqCst) as i64;
    info!("Derived {} boundary changesets", count);

    Ok(thrift::DeriveBoundariesResponse {
        derived_count: count,
        error_message: None,
        ..Default::default()
    })
}

/// Compute derive_slice request - derives a slice of commits (segments defined by head..base ranges)
async fn compute_derive_slice(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    params: thrift::DeriveSliceParams,
) -> Result<thrift::DeriveSliceResponse, AsyncRequestsError> {
    let repo_id = RepositoryId::new(
        params
            .repo_id
            .try_into()
            .map_err(|e| AsyncRequestsError::request(anyhow::anyhow!("Invalid repo_id: {}", e)))?,
    );

    let repo = mononoke
        .repo_by_id(ctx.clone(), repo_id)
        .await
        .map_err(AsyncRequestsError::internal)?
        .ok_or_else(|| {
            AsyncRequestsError::request(anyhow::anyhow!("Repo not found: {}", params.repo_id))
        })?
        .with_authorization_context(AuthorizationContext::new_bypass_access_control())
        .build()
        .await
        .map_err(AsyncRequestsError::internal)?;

    let derived_data_type =
        DerivableType::from_name(&params.derived_data_type).map_err(AsyncRequestsError::request)?;

    // Collect all segment heads - deriving each head will derive everything
    // down to the base (which should already be derived as a boundary).
    let head_cs_ids: Vec<ChangesetId> = params
        .segments
        .iter()
        .map(|seg| ChangesetId::from_bytes(&seg.head))
        .collect::<Result<Vec<_>, _>>()
        .map_err(AsyncRequestsError::request)?;

    info!(
        "Deriving slice with {} segments for repo {} type {:?}",
        head_cs_ids.len(),
        params.repo_id,
        derived_data_type,
    );

    let manager = get_throttled_manager(repo.repo().repo_derived_data().manager())
        .map_err(AsyncRequestsError::internal)?;

    manager
        .derive_bulk_locally(
            ctx,
            &head_cs_ids,
            None, // rederivation
            &[derived_data_type],
            None, // override_batch_size
        )
        .await
        .map_err(|e| AsyncRequestsError::internal(anyhow::anyhow!("{}", e)))?;

    let count = head_cs_ids.len() as i64;
    info!("Derived slice with {} segments", count);

    Ok(thrift::DeriveSliceResponse {
        derived_count: count,
        error_message: None,
        ..Default::default()
    })
}

/// Given the request params dispatches the request to the right processing
/// function and returns the computation result. Both successful computation
/// and error are part of the `AsynchronousRequestResult` structure. We only
/// return `Err` for transient errors, to indicate we should retry.
pub(crate) async fn megarepo_async_request_compute<R: MononokeRepo>(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    megarepo_api: &MegarepoApi<R>,
    params: AsynchronousRequestParams,
) -> Result<AsynchronousRequestResult> {
    match params.into() {
        async_requests_types_thrift::AsynchronousRequestParams::megarepo_add_target_params(params) => {
            Ok(megarepo_add_sync_target(ctx, megarepo_api, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("megarepo_add_sync_target")
                .await
                .map_err(|e| e.into())
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::megarepo_add_branching_target_params(params) => {
            Ok(megarepo_add_branching_sync_target(ctx, megarepo_api, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("megarepo_add_branching_sync_target")
                .await
                .map_err(|e| e.into())
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::megarepo_change_target_params(params) => {
            Ok(megarepo_change_target_config(ctx, megarepo_api, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("megarepo_change_target_config")
                .await
                .map_err(|e| e.into())
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::megarepo_remerge_source_params(params) => {
            Ok(megarepo_remerge_source(ctx, megarepo_api, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("megarepo_remerge_source")
                .await
                .map_err(|e| e.into())
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::megarepo_sync_changeset_params(params) => {
            Ok(megarepo_sync_changeset(ctx, megarepo_api, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("megarepo_sync_changeset")
                .await
                .map_err(|e| e.into())
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::async_ping_params(params) => {
            Ok(Ok(thrift::AsyncPingResponse {
                payload: params.payload,
                ..Default::default()
            }).into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::commit_sparse_profile_size_params(params) => {
            Ok(commit_sparse_profile_size(ctx, mononoke, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("commit_sparse_profile_size")
                .await
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::commit_sparse_profile_delta_params(params) => {
            Ok(commit_sparse_profile_delta(ctx, mononoke, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("commit_sparse_profile_delta")
                .await
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::derive_boundaries_params(params) => {
            Ok(compute_derive_boundaries(ctx, mononoke, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("derive_boundaries")
                .await
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::derive_slice_params(params) => {
            Ok(compute_derive_slice(ctx, mononoke, params)
                .watched()
                .with_max_poll(METHOD_MAX_POLL_TIME_MS)
                .with_label("derive_slice")
                .await
                .into())
        }
        async_requests_types_thrift::AsynchronousRequestParams::UnknownField(union_tag) => {
             bail!(
                "this type of request (AsynchronousRequestParams tag {}) not supported by this worker!", union_tag
             )
        }
    }
}

async fn get_repo_and_changeset(
    ctx: &CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    commit: &CommitSpecifier,
) -> Result<(RepoContext<Repo>, ChangesetContext<Repo>), scs_errors::ServiceError> {
    let changeset_specifier = ChangesetSpecifier::from_request(&commit.id)?;
    let bubble_fetcher = bubble_fetcher_for_changeset(ctx.clone(), changeset_specifier.clone());
    let repo = repo_impl(ctx.clone(), mononoke, &commit.repo, bubble_fetcher).await?;

    let changeset = repo
        .changeset(changeset_specifier)
        .await?
        .ok_or_else(|| scs_errors::commit_not_found(commit.description()))?;

    Ok((repo, changeset))
}

/// Get the repo and pair of changesets specified by a `thrift::CommitSpecifier`
/// and `thrift::CommitId` pair.
async fn repo_changeset_pair(
    ctx: CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    commit: &thrift::CommitSpecifier,
    other_commit: &thrift::CommitId,
) -> Result<
    (
        RepoContext<Repo>,
        ChangesetContext<Repo>,
        ChangesetContext<Repo>,
    ),
    scs_errors::ServiceError,
> {
    let changeset_specifier =
        ChangesetSpecifier::from_request(&commit.id).context("invalid target commit id")?;
    let other_changeset_specifier = ChangesetSpecifier::from_request(other_commit)
        .context("invalid or missing other commit id")?;
    if other_changeset_specifier.in_bubble() {
        Err(scs_errors::invalid_request(format!(
            "Can't compare against a snapshot: {}",
            other_changeset_specifier
        )))?
    }
    let bubble_fetcher = bubble_fetcher_for_changeset(ctx.clone(), changeset_specifier.clone());
    let repo = repo_impl(ctx, mononoke, &commit.repo, bubble_fetcher).await?;
    let (changeset, other_changeset) = try_join!(
        async {
            Ok::<_, scs_errors::ServiceError>(
                repo.changeset(changeset_specifier)
                    .await
                    .context("failed to resolve target commit")?
                    .ok_or_else(|| scs_errors::commit_not_found(commit.description()))?,
            )
        },
        async {
            Ok::<_, scs_errors::ServiceError>(
                repo.changeset(other_changeset_specifier)
                    .await
                    .context("failed to resolve other commit")?
                    .ok_or_else(|| {
                        scs_errors::commit_not_found(format!(
                            "repo={} commit={}",
                            commit.repo.name, other_commit
                        ))
                    })?,
            )
        },
    )?;
    Ok((repo, changeset, other_changeset))
}

fn bubble_fetcher_for_changeset(
    ctx: CoreContext,
    specifier: ChangesetSpecifier,
) -> impl FnOnce(RepoEphemeralStore) -> BoxFuture<'static, anyhow::Result<Option<BubbleId>>> {
    move |ephemeral| async move { specifier.bubble_id(&ctx, ephemeral).await }.boxed()
}

async fn repo_impl<F, R>(
    ctx: CoreContext,
    mononoke: Arc<Mononoke<Repo>>,
    repo: &thrift::RepoSpecifier,
    bubble_fetcher: F,
) -> Result<RepoContext<Repo>, scs_errors::ServiceError>
where
    F: FnOnce(RepoEphemeralStore) -> R,
    R: Future<Output = anyhow::Result<Option<BubbleId>>>,
{
    let repo = mononoke
        .repo(ctx, &repo.name)
        .await?
        .ok_or_else(|| scs_errors::repo_not_found(repo.description()))?
        .with_bubble(bubble_fetcher)
        .await?
        .with_authorization_context(AuthorizationContext::new_bypass_access_control())
        .build()
        .await?;
    Ok(repo)
}
