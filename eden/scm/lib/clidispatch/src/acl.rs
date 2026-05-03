/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::collections::HashSet;
use std::sync::Arc;

use configmodel::Config;
use configmodel::ConfigExt;

use crate::io::IO;

pub fn check_permission_denied_paths(
    paths: &context::PermissionDeniedPaths,
    config: &Arc<dyn Config>,
    io: &IO,
    res: &mut anyhow::Result<u8>,
) -> anyhow::Result<()> {
    let denied = paths.lock();
    if denied.is_empty() {
        return Ok(());
    }

    let mode = config.get_or("slacl", "on-permission-denied", || "error".to_string())?;
    if mode == "ignore" {
        return Ok(());
    }

    let mut seen = HashSet::new();
    for (path, _hgid) in denied.iter() {
        if seen.insert(path) {
            let _ = io.write_err(format!(
                "warning: results may be incomplete, path '{path}' is restricted\n",
            ));
        }
    }

    if mode == "error" {
        if let Ok(code) = res {
            if *code == 0 {
                *code = 1;
            }
        }
    }

    Ok(())
}
