/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Context;
use anyhow::Result;
use anyhow::anyhow;
use async_requests::types::RowId;
use async_requests::types::ThriftAsynchronousRequestParams;
use clap::Args;
use context::CoreContext;
use mononoke_app::MononokeApp;

use crate::commands::async_requests::abort::abort_by_root_id;

#[derive(Args)]
pub(super) struct BackfillAbortArgs {
    /// ID of the derive_backfill request to abort. All pending and
    /// in-progress child requests under this root are also aborted.
    #[clap(long)]
    request_id: u64,
}

pub(super) async fn backfill_abort(
    ctx: CoreContext,
    app: &MononokeApp,
    args: BackfillAbortArgs,
) -> Result<()> {
    let queue = async_requests_client::build(ctx.fb, app, None)
        .await
        .context("acquiring the async requests queue")?;

    let (_request_id, _entry, params, _maybe_result) = queue
        .get_request_by_id(&ctx, &RowId(args.request_id))
        .await
        .context("retrieving the request")?
        .ok_or_else(|| anyhow!("Request {} not found.", args.request_id))?;

    match params.thrift() {
        ThriftAsynchronousRequestParams::derive_backfill_params(_) => {}
        other => {
            return Err(anyhow!(
                "Request {} is not a derive_backfill request (found: {:?}); refusing to abort.",
                args.request_id,
                other,
            ));
        }
    }

    abort_by_root_id(&ctx, &queue, args.request_id).await
}
