/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Global instances of reloadable tracing state.

use std::sync::LazyLock;

pub use tracing_reload::DynWrite;
pub use tracing_reload::ReloadableEnvFilter;

/// Reloadable `EnvFilter` for the `LOG` (`SL_LOG`) environment variable.
pub static LOG_FILTER: ReloadableEnvFilter = ReloadableEnvFilter::new();

/// Reloadable `EnvFilter` for the `BTLOG` (`SL_BTLOG`) environment variable.
/// Controls which targets get backtrace output.
pub static BTLOG_FILTER: ReloadableEnvFilter = ReloadableEnvFilter::new();

/// Reloadable writer for `tracing_subscriber::fmt::Layer` output.
pub static RELOADABLE_WRITER: LazyLock<DynWrite> = LazyLock::new(DynWrite::default);
