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

    let request_access_url_template = config
        .get_or("slacl", "request-access-url-template", String::new)
        .unwrap_or_default();

    let mut warnings = Vec::new();
    let mut seen = HashSet::new();
    for err in denied.iter() {
        let path = &err.path;
        if seen.insert(path) {
            let mut msg =
                format!("warning: results may be incomplete, path '{path}' is restricted");
            if !err.request_acl.is_empty() {
                if !request_access_url_template.is_empty() {
                    let url = request_access_url_template.replace("{acl}", &err.request_acl);
                    msg.push_str(&format!(" (request access: {})", url));
                } else {
                    msg.push_str(&format!(" (ACL: {})", err.request_acl));
                }
            }
            msg.push('\n');
            warnings.push(msg);
        }
    }

    Ok(PermissionDeniedResult {
        exit_nonzero: mode == "error",
        warnings,
    })
}
