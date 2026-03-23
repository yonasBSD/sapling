/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Result;
use bulk_derivation::BulkDerivation;
use clap::Args;
use context::CoreContext;
use derived_data_manager::DerivedDataManager;
use mononoke_app::args::ChangesetArgs;
use mononoke_app::args::DerivedDataArgs;

use super::Repo;

#[derive(Args)]
pub(super) struct VerifyStageOutputArgs {
    #[clap(flatten)]
    changeset_args: ChangesetArgs,

    #[clap(flatten)]
    derived_data_args: DerivedDataArgs,

    /// The stage ID to verify (e.g. "root", "dir1")
    #[clap(long)]
    stage: String,
}

pub(super) async fn verify_stage_output(
    ctx: &CoreContext,
    repo: &Repo,
    manager: &DerivedDataManager,
    args: VerifyStageOutputArgs,
) -> Result<()> {
    let cs_ids = args.changeset_args.resolve_changesets(ctx, repo).await?;
    let derived_data_type = args.derived_data_args.resolve_type()?;

    for cs_id in cs_ids {
        match BulkDerivation::verify_stage_output(
            manager,
            ctx,
            cs_id,
            derived_data_type,
            &args.stage,
        )
        .await
        {
            Ok(true) => println!("{}: Match", cs_id),
            Ok(false) => println!("{}: Mismatch", cs_id),
            Err(e) => println!("{}: Error: {:#}", cs_id, e),
        }
    }

    Ok(())
}
