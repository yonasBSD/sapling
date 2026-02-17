/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::fs::File;
use std::io::Write;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;

use anyhow::Context;
use anyhow::Result;
use async_trait::async_trait;
use clap::Parser;
use fb303_core::fb303_status;
use fb303_core_services::BaseService;
use fb303_core_services::errors::GetNameExn;
use fb303_core_services::errors::GetStatusDetailsExn;
use fb303_core_services::errors::GetStatusExn;
use fb303_core_services::make_BaseService_server;
use fbinit::FacebookInit;
use mononoke_app::MononokeAppBuilder;
use mononoke_app::args::ShutdownTimeoutArgs;
use multi_repo_land_if_services::make_MultiRepoLandService_server;
use srserver::ThriftServerBuilder;
use srserver::service_framework::BuildModule;
use srserver::service_framework::Fb303Module;
use srserver::service_framework::ServiceFramework;
use srserver::service_framework::ThriftStatsModule;

mod methods;
mod repo;
mod service;

use crate::service::MultiRepoLandServiceImpl;

const SERVICE_NAME: &str = "multi_repo_land_service";

/// Fb303 BaseService implementation that reports server status.
#[derive(Clone)]
struct BaseServiceImpl {
    will_exit: Arc<AtomicBool>,
}

#[async_trait]
impl BaseService for BaseServiceImpl {
    async fn getName(&self) -> Result<String, GetNameExn> {
        Ok(SERVICE_NAME.to_string())
    }

    async fn getStatus(&self) -> Result<fb303_status, GetStatusExn> {
        if self.will_exit.load(Ordering::Relaxed) {
            Ok(fb303_status::STOPPING)
        } else {
            Ok(fb303_status::ALIVE)
        }
    }

    async fn getStatusDetails(&self) -> Result<String, GetStatusDetailsExn> {
        if self.will_exit.load(Ordering::Relaxed) {
            Ok("Shutting down.".to_string())
        } else {
            Ok("Alive and running.".to_string())
        }
    }
}

/// Multi-Repo Land Service: atomically moves bookmarks across multiple repositories.
#[derive(Parser)]
struct MultiRepoLandServiceArgs {
    #[clap(flatten)]
    shutdown_timeout_args: ShutdownTimeoutArgs,

    /// Thrift host.
    #[clap(long, default_value = "::")]
    host: String,

    /// Port to listen on.
    #[clap(long, short = 'p', default_value_t = 8380)]
    port: u16,

    /// Path for file in which to write the bound tcp address.
    #[clap(long)]
    bound_address_file: Option<String>,
}

#[fbinit::main]
fn main(fb: FacebookInit) -> Result<()> {
    let app = MononokeAppBuilder::new(fb)
        .with_default_scuba_dataset("mononoke_multi_repo_land")
        .build::<MultiRepoLandServiceArgs>()?;

    let args: MultiRepoLandServiceArgs = app.args()?;
    let env = app.environment();
    let runtime = app.runtime();
    let repos_mgr = Arc::new(runtime.block_on(app.open_managed_repos::<repo::Repo>(None))?);
    let service = Arc::new(MultiRepoLandServiceImpl::new(
        fb,
        repos_mgr,
        env.scuba_sample_builder.clone(),
    ));

    let will_exit = Arc::new(AtomicBool::new(false));

    let fb303_base = {
        let will_exit = will_exit.clone();
        move |proto| {
            make_BaseService_server(
                proto,
                BaseServiceImpl {
                    will_exit: will_exit.clone(),
                },
            )
        }
    };

    let thrift_service = {
        let service = service.clone();
        move |proto| make_MultiRepoLandService_server(proto, service.clone(), fb303_base.clone())
    };

    let thrift = ThriftServerBuilder::new(fb)
        .with_name(SERVICE_NAME)
        .expect("failed to set service name")
        .with_address(&args.host, args.port, false)?
        .with_tls()
        .expect("failed to enable TLS")
        .with_cancel_if_client_disconnected()
        .add_factory(runtime.clone(), move || thrift_service, None)
        .build();

    let mut service_framework = ServiceFramework::from_server(SERVICE_NAME, thrift)
        .context("failed to create service framework")?;
    service_framework.add_module(BuildModule)?;
    service_framework.add_module(ThriftStatsModule)?;
    service_framework.add_module(Fb303Module)?;
    service_framework
        .serve_background()
        .expect("failed to start thrift service");

    let bound_addr = format!(
        "{}:{}",
        &args.host,
        service_framework.get_address()?.get_port()?
    );

    if let Some(bound_addr_path) = args.bound_address_file {
        let mut writer = File::create(bound_addr_path)?;
        writer.write_all(bound_addr.as_bytes())?;
        writer.write_all(b"\n")?;
    }

    app.start_stats_aggregation()?;

    app.wait_until_terminated(
        move || will_exit.store(true, Ordering::Relaxed),
        args.shutdown_timeout_args.shutdown_grace_period,
        async {
            let _ = tokio::task::spawn_blocking(move || {
                service_framework.stop();
            })
            .await;
        },
        args.shutdown_timeout_args.shutdown_timeout,
        None,
    )?;

    Ok(())
}
