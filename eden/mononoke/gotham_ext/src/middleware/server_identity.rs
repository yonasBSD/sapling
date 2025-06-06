/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::env;

use anyhow::Error;
use gotham::helpers::http::header::X_REQUEST_ID;
use gotham::state::State;
use hyper::Body;
use hyper::Response;
use hyper::header::HeaderValue;

use super::Middleware;
use crate::state_ext::StateExt;

pub struct ServerIdentityMiddleware {
    headers: HashMap<&'static str, HeaderValue>,
}

impl ServerIdentityMiddleware {
    pub fn new(server_name: HeaderValue) -> Self {
        let mut headers = HashMap::new();

        headers.insert("Server", server_name);

        // NOTE: We ignore errors here — those will happen if environment variables are missing,
        // which is fine.
        let _ = Self::add_tw_task(&mut headers);
        let _ = Self::add_tw_task_version(&mut headers);
        let _ = Self::add_tw_canary_id(&mut headers);

        Self { headers }
    }

    fn add_tw_task(headers: &mut HashMap<&'static str, HeaderValue>) -> Result<(), Error> {
        let tw_job_cluster = env::var("TW_JOB_CLUSTER")?;
        let tw_job_user = env::var("TW_JOB_USER")?;
        let tw_job_name = env::var("TW_JOB_NAME")?;
        let tw_task_id = env::var("TW_TASK_ID")?;
        let task = format!(
            "{}/{}/{}/{}",
            tw_job_cluster, tw_job_user, tw_job_name, tw_task_id
        );
        let header = HeaderValue::from_str(&task)?;
        headers.insert("X-TW-Task", header);
        Ok(())
    }

    fn add_tw_task_version(headers: &mut HashMap<&'static str, HeaderValue>) -> Result<(), Error> {
        let tw_task_version = env::var("TW_TASK_VERSION")?;
        let header = HeaderValue::from_str(&tw_task_version)?;
        headers.insert("X-TW-Task-Version", header);
        Ok(())
    }

    fn add_tw_canary_id(headers: &mut HashMap<&'static str, HeaderValue>) -> Result<(), Error> {
        let tw_canary_id = env::var("TW_CANARY_ID")?;
        let header = HeaderValue::from_str(&tw_canary_id)?;
        headers.insert("X-TW-Canary-Id", header);
        Ok(())
    }
}

#[async_trait::async_trait]
impl Middleware for ServerIdentityMiddleware {
    async fn outbound(&self, state: &mut State, response: &mut Response<Body>) {
        let headers = response.headers_mut();

        for (header, value) in self.headers.iter() {
            headers.insert(*header, value.clone());
        }

        if let Ok(id) = HeaderValue::from_str(state.short_request_id()) {
            headers.insert(X_REQUEST_ID, id);
        }
    }
}
