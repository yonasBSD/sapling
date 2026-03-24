/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Configure various libraries
//!
//! After loading the config files, configure related libraries accordingly.
//!
//! Note: this only affects `sl` CLI. For EdenFS, you might also need to update
//! `lib/backingstore`.
//!
//! Some libraries take Sapling's `Config` trait for configuration. Some
//! libraries like `hgtime` are low-level and shouldn't depend on Sapling's
//! `Config` trait. Their configuration logic is here.
//!
//! For initialization that does not need a `config`.
//! Check `lib/constructors` - it affects both `sl` and `eden`
//! (via `lib/backingstore`).

use configmodel::Config;
use configmodel::ConfigExt;
use hgtime::HgTime;
use io::IO;
use repo::CoreRepo;

use crate::OptionalRepo;
use crate::dispatch::Dispatcher;
use crate::dispatch::Result;

impl Dispatcher {
    pub(crate) fn configure_libraries(&self, _io: &IO) -> Result<()> {
        let config = self.config();
        indexedlog::config::configure(config)?;
        gitcompat::GlobalGit::set_default_config(config);
        initialize_hgtime(config)?;
        initialize_blackbox(&self.optional_repo)?;

        Ok(())
    }
}

fn initialize_blackbox(optional_repo: &OptionalRepo) -> Result<()> {
    if let OptionalRepo::CoreRepo(CoreRepo::Disk(repo)) = optional_repo {
        let config = repo.config();

        if !config.get_or("blackbox", "enable", || true)? {
            tracing::debug!("blackbox disabled");
            return Ok(());
        }

        let max_size = config
            .get_or("blackbox", "maxsize", || {
                configloader::convert::ByteCount::from(1u64 << 12)
            })?
            .value();
        let max_files = config.get_or("blackbox", "maxfiles", || 3)?;
        let path = repo.shared_dot_hg_path().join("blackbox/v1");
        if let Ok(blackbox) = ::blackbox::BlackboxOptions::new()
            .max_bytes_per_log(max_size)
            .max_log_count(max_files as u8)
            .open(path)
        {
            ::blackbox::init(blackbox);
        }
    }
    Ok(())
}

fn initialize_hgtime(config: &dyn Config) -> Result<()> {
    let mut should_clear = true;
    if let Some(now_str) = config.get("devel", "default-date") {
        let now_str = now_str.trim();
        if !now_str.is_empty() {
            if let Some(now) = HgTime::parse(now_str) {
                tracing::info!(?now, "set 'now' for testing");
                now.set_as_now_for_testing();
                should_clear = false;
            }
        }
    }
    if should_clear {
        tracing::debug!("unset 'now' for testing");
        HgTime::clear_now_for_testing();
    }
    Ok(())
}
