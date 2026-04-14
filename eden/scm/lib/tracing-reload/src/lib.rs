/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Provides reloadable `tracing_subscriber::EnvFilter` and `io::Write` wrappers.
//!
//! These can be swapped at runtime without replacing the global subscriber.

use std::io;
use std::io::Write;
use std::sync::Arc;
use std::sync::Mutex;

use anyhow::Result;
use anyhow::bail;
use tracing::Subscriber;
use tracing_subscriber::EnvFilter;
use tracing_subscriber::reload;

/// Reloadable `EnvFilter` state. Can be stored in a `static`.
///
/// ```ignore
/// static MY_FILTER: ReloadableEnvFilter = ReloadableEnvFilter::new();
///
/// // Create the filter layer (once):
/// let layer = MY_FILTER.env_filter()?;
///
/// // Update directives at runtime:
/// MY_FILTER.update_directives("foo=debug")?;
/// ```
pub struct ReloadableEnvFilter {
    updater: Mutex<Option<Box<dyn Fn(&str) -> Result<()> + Send + Sync>>>,
    directives: Mutex<String>,
}

impl ReloadableEnvFilter {
    pub const fn new() -> Self {
        Self {
            updater: Mutex::new(None),
            directives: Mutex::new(String::new()),
        }
    }

    /// Update directives. If the filter layer has been created, reloads it
    /// immediately. Otherwise, buffers the directives for later.
    pub fn update_directives(&self, dirs: &str) -> Result<()> {
        *self.directives.lock().unwrap() = dirs.to_string();
        let locked = self.updater.lock().unwrap();
        if let Some(func) = locked.as_ref() {
            (func)(dirs)
        } else {
            Ok(())
        }
    }

    /// Create a reloadable `EnvFilter` layer. Can only be called once per
    /// instance — a second call returns an error.
    pub fn env_filter<S: Subscriber>(&self) -> Result<reload::Layer<EnvFilter, S>> {
        let mut locked = self.updater.lock().unwrap();
        if locked.is_some() {
            bail!("reloadable EnvFilter already created for this instance");
        }
        let dirs = self.directives.lock().unwrap();
        let layer = new_env_filter(&dirs)?;
        let (layer, handle) = reload::Layer::new(layer);
        let update = move |dirs: &str| -> Result<()> {
            handle.reload(new_env_filter(dirs)?)?;
            Ok(())
        };
        *locked = Some(Box::new(update));
        Ok(layer)
    }
}

fn new_env_filter(dirs: &str) -> Result<EnvFilter, tracing_subscriber::filter::ParseError> {
    if dirs.is_empty() {
        Ok(EnvFilter::default())
    } else {
        EnvFilter::try_new(dirs)
    }
}

/// A cloneable, swappable `io::Write`. All clones share the same inner writer.
#[derive(Clone)]
pub struct DynWrite(Arc<Mutex<Box<dyn Write + Send + Sync + 'static>>>);

impl Default for DynWrite {
    fn default() -> Self {
        Self(Arc::new(Mutex::new(Box::new(io::sink()))))
    }
}

impl DynWrite {
    /// Replace the inner writer. Takes effect immediately for all clones.
    pub fn update(&self, writer: Box<dyn Write + Send + Sync + 'static>) {
        *self.0.lock().unwrap() = writer;
    }
}

impl Write for DynWrite {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.0.lock().unwrap().write(buf)
    }
    fn flush(&mut self) -> io::Result<()> {
        self.0.lock().unwrap().flush()
    }
}
