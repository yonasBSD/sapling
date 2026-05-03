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

pub struct PermissionDeniedResult {
    pub warnings: Vec<String>,
    pub exit_nonzero: bool,
}

pub fn check_permission_denied_paths(
    paths: &context::PermissionDeniedPaths,
    config: &Arc<dyn Config>,
) -> anyhow::Result<PermissionDeniedResult> {
    let denied = paths.lock();
    if denied.is_empty() {
        return Ok(PermissionDeniedResult {
            warnings: Vec::new(),
            exit_nonzero: false,
        });
    }

    let mode = config.get_or("slacl", "on-permission-denied", || "error".to_string())?;
    if mode == "ignore" {
        return Ok(PermissionDeniedResult {
            warnings: Vec::new(),
            exit_nonzero: false,
        });
    }

    let mut warnings = Vec::new();
    let mut seen = HashSet::new();
    for (path, _hgid) in denied.iter() {
        if seen.insert(path) {
            warnings.push(format!(
                "warning: results may be incomplete, path '{path}' is restricted\n",
            ));
        }
    }

    Ok(PermissionDeniedResult {
        exit_nonzero: mode == "error",
        warnings,
    })
}
