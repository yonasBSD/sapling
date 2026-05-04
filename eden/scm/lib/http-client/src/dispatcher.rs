/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::sync::Arc;

use futures::prelude::*;

use crate::StatsFuture;
use crate::client::WorkerClient;
use crate::errors::HttpClientError;
use crate::request::StreamRequest;

pub(crate) trait AsyncRequestDispatcher: Send + Sync {
    fn dispatch(
        &self,
        client: WorkerClient,
        requests: Vec<StreamRequest>,
    ) -> Result<StatsFuture, HttpClientError>;
}

pub(crate) struct SpawnBlockingDispatcher;

impl AsyncRequestDispatcher for SpawnBlockingDispatcher {
    fn dispatch(
        &self,
        client: WorkerClient,
        requests: Vec<StreamRequest>,
    ) -> Result<StatsFuture, HttpClientError> {
        let task = async_runtime::spawn_blocking(move || client.stream(requests));
        Ok(task.err_into::<HttpClientError>().map(|res| res?).boxed())
    }
}

pub(crate) fn spawn_blocking_dispatcher() -> Arc<dyn AsyncRequestDispatcher> {
    Arc::new(SpawnBlockingDispatcher)
}
