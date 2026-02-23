/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use mononoke_types::NonRootMPath;

/// Information about a restriction that applies to a path.
#[derive(Clone, Debug, PartialEq)]
pub struct PathRestrictionInfo {
    /// The root path of the restriction that covers this path.
    /// For example, if `foo/bar/` is restricted and we query `foo/bar/baz.txt`,
    /// this would be `foo/bar/`.
    pub restriction_root: NonRootMPath,

    /// The repo region ACL identity string that governs access to this restriction root.
    pub repo_region_acl: String,

    /// Whether the caller has access. None if access was not checked.
    pub has_access: Option<bool>,

    /// ACL to direct the user to for requesting access.
    /// If no specific request ACL is configured, this defaults to the repo_region_acl.
    pub request_acl: String,
}
