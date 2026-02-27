/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::path::PathBuf;
use std::process::Command;

use anyhow::Result;
use configmodel::Config;
use configmodel::ConfigExt;

pub fn build_eden_command(config: &dyn Config) -> Result<Command> {
    let eden_command = config.get_opt::<String>("edenfs", "command")?;
    let mut cmd = match eden_command {
        Some(cmd) => Command::new(cmd),
        None => anyhow::bail!("edenfs.command config is not set"),
    };

    // allow tests to specify different configuration directories from prod defaults
    if let Some(base_dir) = config.get_opt::<PathBuf>("edenfs", "basepath")? {
        cmd.args([
            "--config-dir".into(),
            base_dir.join("eden"),
            "--etc-eden-dir".into(),
            base_dir.join("etc_eden"),
            "--home-dir".into(),
            base_dir.join("home"),
        ]);
    }
    Ok(cmd)
}
