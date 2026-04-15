/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;

use anyhow::Error;
use anyhow::bail;
use async_requests::AsyncMethodRequestQueue;
use async_requests::QueueRepoFilter;
use blobstore::Blobstore;
use blobstore_factory::make_blobstore;
use fbinit::FacebookInit;
use mononoke_app::MononokeApp;
use mononoke_types::RepositoryId;
use requests_table::SqlLongRunningRequestsQueue;
use sql_construct::SqlConstructFromDatabaseConfig;
use tracing::debug;

/// Build a new async requests queue client. If `repos` is specified, the
/// client will only operate on requests for those repos. Otherwise it
/// operates on requests for any repo.
pub async fn build(
    fb: FacebookInit,
    app: &MononokeApp,
    repos: Option<Vec<RepositoryId>>,
) -> Result<AsyncMethodRequestQueue, Error> {
    let sql_connection = Arc::new(open_sql_connection(fb, app).await?);
    let blobstore = Arc::new(open_blobstore(fb, app).await?);
    let repo_filter = match repos {
        Some(repos) => QueueRepoFilter::Only(repos),
        None => QueueRepoFilter::Except(vec![]),
    };

    Ok(AsyncMethodRequestQueue::new(
        sql_connection,
        blobstore,
        repo_filter,
    ))
}

pub async fn open_sql_connection(
    fb: FacebookInit,
    app: &MononokeApp,
) -> Result<SqlLongRunningRequestsQueue, Error> {
    let config = app.repo_configs().common.async_requests_config.clone();
    if let Some(config) = config.db_config {
        debug!("Initializing async_requests with an explicit config");
        SqlLongRunningRequestsQueue::with_database_config(fb, &config, app.mysql_options(), false)
    } else {
        bail!("async_requests config is missing");
    }
}

pub async fn open_blobstore(
    fb: FacebookInit,
    app: &MononokeApp,
) -> Result<Arc<dyn Blobstore>, Error> {
    let config = app.repo_configs().common.async_requests_config.clone();
    if let Some(config) = config.blobstore {
        make_blobstore(
            fb,
            config,
            app.mysql_options(),
            blobstore_factory::ReadOnlyStorage(false),
            app.blobstore_options(),
            app.config_store(),
            &blobstore_factory::default_scrub_handler(),
            None,
            None,
        )
        .await
    } else {
        bail!("async_requests config is missing");
    }
}
