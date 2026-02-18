/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Context;
use anyhow::Result;
use async_requests::AsyncMethodRequestQueue;
use async_requests::types::RowId;
use async_requests::types::Token;
use bulk_derivation::BulkDerivation;
use clap::Args;
use commit_graph::CommitGraphRef;
use context::CoreContext;
use derived_data_manager::DerivedDataManager;
use futures_stats::TimedTryFutureExt;
use mononoke_app::MononokeApp;
use mononoke_app::args::ChangesetArgs;
use mononoke_app::args::DerivedDataArgs;
use mononoke_app::args::RepoArgs;
use repo_derived_data::RepoDerivedDataRef;
use repo_identity::RepoIdentityRef;
use source_control as thrift;
use tracing::info;

use super::Repo;

#[derive(Args)]
pub(super) struct BackfillEnqueueArgs {
    #[clap(flatten)]
    changeset_args: ChangesetArgs,

    #[clap(flatten)]
    derived_data_args: DerivedDataArgs,

    /// The size of each slice in generation numbers
    #[clap(long, default_value_t = 50000)]
    slice_size: u64,

    /// Concurrency for boundary derivation requests
    #[clap(long, default_value_t = 10)]
    boundaries_concurrency: i32,

    /// Whether to rederive already-derived changesets
    #[clap(long)]
    pub(crate) rederive: bool,

    /// Repositories to backfill (comma-separated names).
    /// If provided, overrides the top-level --repo-name/--repo-id.
    #[clap(long, value_delimiter = ',')]
    repos: Vec<String>,
}

pub(super) async fn backfill_enqueue(
    ctx: &CoreContext,
    app: &MononokeApp,
    default_repo: &Repo,
    default_manager: &DerivedDataManager,
    queue: AsyncMethodRequestQueue,
    args: BackfillEnqueueArgs,
    config_name: Option<&str>,
    bypass_redaction: bool,
) -> Result<()> {
    if args.repos.is_empty() {
        enqueue_repo_backfill(ctx, default_repo, default_manager, &queue, &args).await
    } else {
        for repo_name in &args.repos {
            info!("Processing repo: {}", repo_name);
            let repo_arg = RepoArgs::from_repo_name(repo_name.clone());
            let repo: Repo =
                super::open_repo_for_derive(app, &repo_arg, args.rederive, bypass_redaction)
                    .await
                    .with_context(|| format!("Failed to open repo: {}", repo_name))?;

            let manager = if let Some(name) = config_name {
                repo.repo_derived_data().manager_for_config(name)?
            } else {
                repo.repo_derived_data().manager()
            };
            enqueue_repo_backfill(ctx, &repo, manager, &queue, &args)
                .await
                .with_context(|| format!("Failed to enqueue for repo: {}", repo_name))?;
        }
        Ok(())
    }
}

async fn enqueue_repo_backfill(
    ctx: &CoreContext,
    repo: &Repo,
    manager: &DerivedDataManager,
    queue: &AsyncMethodRequestQueue,
    args: &BackfillEnqueueArgs,
) -> Result<()> {
    let mut cs_ids = args.changeset_args.resolve_changesets(ctx, repo).await?;
    let derived_data_type = args.derived_data_args.resolve_type()?;
    let repo_id = repo.repo_identity().id();

    info!(
        "Computing slices for {} changesets, type {:?}, slice_size {}",
        cs_ids.len(),
        derived_data_type,
        args.slice_size,
    );

    // Filter to only underived changesets (unless rederive is set)
    if !args.rederive {
        cs_ids = manager
            .pending(ctx, &cs_ids, None, derived_data_type)
            .await?;
        if cs_ids.is_empty() {
            info!("All changesets already derived, nothing to enqueue");
            return Ok(());
        }
        info!("{} changesets still underived", cs_ids.len());
    }

    // Find the derived frontier - changesets whose ancestors are already derived
    let excluded_ancestors = if args.rederive {
        vec![]
    } else {
        let (frontier_stats, frontier) = repo
            .commit_graph()
            .ancestors_frontier_with(ctx, cs_ids.clone(), |cs_id| async move {
                Ok(manager
                    .is_derived(ctx, cs_id, None, derived_data_type)
                    .await?)
            })
            .try_timed()
            .await?;
        info!(
            "Computed derived frontier ({} changesets) in {}ms",
            frontier.len(),
            frontier_stats.completion_time.as_millis(),
        );
        frontier
    };

    // Compute slices and boundary changesets
    let (slices_stats, (slices, boundary_changesets)) = repo
        .commit_graph()
        .segmented_slice_ancestors(ctx, cs_ids, excluded_ancestors, args.slice_size)
        .try_timed()
        .await?;
    info!(
        "Computed {} slices with {} boundary changesets in {}ms",
        slices.len(),
        boundary_changesets.len(),
        slices_stats.completion_time.as_millis(),
    );

    if slices.is_empty() && boundary_changesets.is_empty() {
        info!("Nothing to enqueue");
        return Ok(());
    }

    // Step 1: Enqueue boundary derivation request (no dependencies)
    let boundary_cs_bytes: Vec<Vec<u8>> = boundary_changesets
        .iter()
        .map(|cs_id| cs_id.as_ref().to_vec())
        .collect();

    let boundary_params = thrift::DeriveBoundariesParams {
        repo_id: repo_id.id() as i64,
        derived_data_type: derived_data_type.name().to_string(),
        boundary_cs_ids: boundary_cs_bytes,
        concurrency: args.boundaries_concurrency,
        use_predecessor_derivation: derived_data_type
            .into_derivable_untopologically_variant()
            .is_ok(),
        ..Default::default()
    };

    let boundary_token = queue
        .enqueue(ctx, Some(&repo_id), boundary_params)
        .await
        .context("Failed to enqueue boundary derivation request")?;
    let boundary_row_id = boundary_token.id();
    info!(
        "Enqueued boundary derivation request (id={}, {} changesets)",
        boundary_row_id.0,
        boundary_changesets.len(),
    );

    // Step 2: Enqueue slice derivation requests with dependency on boundaries
    let serial_slices = derived_data_type
        .into_derivable_untopologically_variant()
        .is_err();
    let mut prev_slice_row_id: Option<RowId> = None;

    for (i, slice) in slices.iter().enumerate() {
        let segments: Vec<thrift::DeriveSliceSegment> = slice
            .segments
            .iter()
            .map(|seg| thrift::DeriveSliceSegment {
                head: seg.head.as_ref().to_vec(),
                base: seg.base.as_ref().to_vec(),
                ..Default::default()
            })
            .collect();

        let slice_params = thrift::DeriveSliceParams {
            repo_id: repo_id.id() as i64,
            derived_data_type: derived_data_type.name().to_string(),
            segments,
            ..Default::default()
        };

        // Each slice depends on the boundary derivation request.
        // For types requiring serial processing, each slice also depends
        // on the previous slice.
        let mut depends_on = vec![boundary_row_id.clone()];
        if serial_slices {
            if let Some(prev_id) = &prev_slice_row_id {
                depends_on.push(prev_id.clone());
            }
        }

        let slice_token = queue
            .enqueue_with_dependencies(ctx, Some(&repo_id), slice_params, &depends_on)
            .await
            .context("Failed to enqueue slice derivation request")?;
        let slice_row_id = slice_token.id();
        info!(
            "Enqueued slice {}/{} (id={}, {} segments)",
            i + 1,
            slices.len(),
            slice_row_id.0,
            slice.segments.len(),
        );

        if serial_slices {
            prev_slice_row_id = Some(slice_row_id);
        }
    }

    info!(
        "Enqueued {} total requests (1 boundary + {} slices)",
        1 + slices.len(),
        slices.len(),
    );

    Ok(())
}
