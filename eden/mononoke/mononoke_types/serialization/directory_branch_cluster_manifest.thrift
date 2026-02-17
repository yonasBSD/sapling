/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! ------------
//! IMPORTANT!!!
//! ------------
//! Do not change the order of the fields! Changing the order of the fields
//! results in compatible but *not* identical serializations, so hashes will
//! change.
//! ------------
//! IMPORTANT!!!
//! ------------

include "eden/mononoke/mononoke_types/serialization/path.thrift"
include "eden/mononoke/mononoke_types/serialization/sharded_map.thrift"
include "thrift/annotation/rust.thrift"

package "facebook.com/eden/mononoke/mononoke_types/serialization"

// Directory Branch Cluster Manifest tracks "directory branch clusters" - sets of directories
// that are copies/branches of each other via subtree operations. This enables Code Search
// to deduplicate results across directory branches.
//
// Each directory stores bidirectional cluster membership:
// - `secondaries`: If this directory is a cluster primary, lists paths copied FROM it
// - `primary`: If this directory is a secondary, the path it was copied FROM
//
// For example, if directory A is copied to B:
// - A's secondaries = [B]
// - B's primary = A
//
// Note: Unlike other manifests, DBCM only stores directories (no files). The manifest
// tracks cluster relationships between directories, which files don't have.
@rust.Exhaustive
struct DirectoryBranchClusterManifest {
  /// Map of MPathElement -> DirectoryBranchClusterManifest (subdirectories only)
  1: sharded_map.ShardedMapV2Node subentries;
  /// If this directory is a cluster primary, lists its secondaries (paths copied FROM this directory)
  2: optional list<path.MPath> secondaries;
  /// If this directory is a cluster secondary, the path it was copied FROM
  3: optional path.MPath primary;
}

@rust.Exhaustive
struct DirectoryBranchClusterManifestFile {
  /// If this directory is a cluster primary, lists its secondaries (paths copied FROM this directory)
  2: optional list<path.MPath> secondaries;
  /// If this directory is a cluster secondary, the path it was copied FROM
  3: optional path.MPath primary;
}

union DirectoryBranchClusterManifestEntry {
  1: DirectoryBranchClusterManifestFile file;
  2: DirectoryBranchClusterManifest directory;
}
