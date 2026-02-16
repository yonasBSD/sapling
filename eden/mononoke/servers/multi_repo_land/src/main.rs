/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;

use anyhow::Result;
use clap::Parser;
use fbinit::FacebookInit;
use mononoke_app::MononokeAppBuilder;
use mononoke_app::args::ShutdownTimeoutArgs;

mod repo;
mod service;

use crate::service::MultiRepoLandServiceImpl;

const SERVICE_NAME: &str = "multi_repo_land_service";

/// Multi-Repo Land Service: atomically moves bookmarks across multiple repositories.
#[derive(Parser)]
struct MultiRepoLandServiceArgs {
    #[clap(flatten)]
    shutdown_timeout_args: ShutdownTimeoutArgs,

    /// Port to listen on.
    #[clap(long, short = 'p', default_value_t = 8380)]
    port: u16,
}

#[fbinit::main]
fn main(fb: FacebookInit) -> Result<()> {
    let app = MononokeAppBuilder::new(fb).build::<MultiRepoLandServiceArgs>()?;

    let args: MultiRepoLandServiceArgs = app.args()?;
    let runtime = app.runtime();
    let repos_mgr = Arc::new(runtime.block_on(app.open_managed_repos::<repo::Repo>(None))?);
    let _service = MultiRepoLandServiceImpl::new(repos_mgr);

    // TODO: Wire up Thrift server in a later task

    app.wait_until_terminated(
        || {},
        args.shutdown_timeout_args.shutdown_grace_period,
        async {},
        args.shutdown_timeout_args.shutdown_timeout,
        None,
    )?;

    Ok(())
}
