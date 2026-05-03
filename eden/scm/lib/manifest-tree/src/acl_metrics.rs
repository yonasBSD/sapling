/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use metrics::Counter;

/// Trees that were proactively marked as permission-denied via
/// `permission_denied_children` (the "intelligent" pre-check that
/// avoids fetching restricted trees entirely).
pub static ACL_AVOIDED: Counter = Counter::new_counter("manifest_tree.acl_avoided");

/// Trees where the server returned a PermissionDenied error
/// (i.e. we tried to fetch and were rejected).
pub static ACL_DENIED: Counter = Counter::new_counter("manifest_tree.acl_denied");
