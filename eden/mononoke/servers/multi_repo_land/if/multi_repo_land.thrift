/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

include "fb303/thrift/fb303_core.thrift"
include "eden/mononoke/scs/if/source_control.thrift"
include "thrift/annotation/rust.thrift"
include "thrift/annotation/thrift.thrift"

package "facebook.com/eden/mononoke/servers/multi_repo_land"

// === Fetch Manifest Content ===

@rust.Exhaustive
struct RepoFetchManifestContentParams {
  /// The repo containing the manifest file.
  1: source_control.RepoSpecifier repo;
  /// The bookmark for which the static manifest contents are requested.
  2: string bookmark;
  /// The UTF-8 path of the static manifest file relative to the repo root.
  3: string path;
}

@rust.Exhaustive
struct RepoFetchManifestContentResponse {
  1: binary manifest_content;
}

// === Multi-Repo Bookmark Modification ===

@rust.Exhaustive
struct RepoBookmarkModification {
  /// Repository that this bookmark is located in.
  1: source_control.RepoSpecifier repo;
  /// Name of the bookmark to modify.
  2: string bookmark_name;
  /// Modification to perform.
  3: RepoBookmarkModificationSpec modification;
  /// The pushvars to use when modifying the bookmark.
  4: optional map<string, binary> pushvars;
}

union RepoBookmarkModificationSpec {
  1: RepoBookmarkModificationCreate create_bookmark;
  2: RepoBookmarkModificationMove move_bookmark;
  3: RepoBookmarkModificationDelete delete_bookmark;
}

@rust.Exhaustive
struct RepoBookmarkModificationCreate {
  /// New bookmark location. The bookmark must not already exist.
  1: source_control.CommitId target;
}

@rust.Exhaustive
struct RepoBookmarkModificationMove {
  /// New bookmark location.
  1: source_control.CommitId target;
  /// Expected old bookmark location. If the bookmark wasn't pointing here
  /// then the whole set of bookmark moves will fail.
  2: optional source_control.CommitId old_target;
  /// Whether non-fast-forward moves are allowed.
  3: bool allow_non_fast_forward_move;
}

@rust.Exhaustive
struct RepoBookmarkModificationDelete {
  /// Previous bookmark location. The bookmark must exist and point here.
  1: optional source_control.CommitId old_target;
}

@rust.Exhaustive
struct ManifestBookmarkModification {
  /// Repository that the manifest bookmark is in.
  1: source_control.RepoSpecifier repo;
  /// Name of the bookmark to modify.
  2: string bookmark_name;
  /// Content of manifest file for the specific bookmark.
  3: binary manifest_content;
}

@rust.Exhaustive
struct MultipleRepoModifyBookmarksParams {
  /// List of modifications to make to bookmarks in various repos.
  1: list<RepoBookmarkModification> repo_bookmark_modifications;
  /// List of modifications to make to bookmarks in manifest repo.
  2: list<ManifestBookmarkModification> manifest_bookmark_modifications;
  /// Service identity for automation.
  3: optional string service_identity;
}

// === Response Types ===

@rust.Exhaustive
struct RepoBookmarkResult {
  1: string repo_name;
  2: string bookmark_name;
}

@rust.Exhaustive
struct MultipleRepoModifyBookmarksResponse {
  1: list<RepoBookmarkResult> results;
}

@rust.Exhaustive
struct RebasedCommitEntry {
  1: string repo_name;
  2: string bookmark_name;
  3: source_control.CommitId original_commit;
  4: source_control.CommitId rebased_commit;
  5: source_control.CommitId new_bookmark_target;
}

@rust.Exhaustive
struct RebaseConflictEntry {
  1: string repo_name;
  2: string bookmark_name;
  3: source_control.CommitId original_commit;
  4: source_control.CommitId current_bookmark_target;
  5: string conflict_description;
}

// === Exceptions ===

@rust.Exhaustive
safe permanent client exception MultiRepoLandCasFailure {
  @thrift.ExceptionMessage
  1: string message;
  2: list<RebasedCommitEntry> rebased_commits;
}

@rust.Exhaustive
safe permanent client exception MultiRepoLandRebaseConflict {
  @thrift.ExceptionMessage
  1: string message;
  2: list<RebaseConflictEntry> conflicts;
}

// === Service ===

@rust.RequestContext
service MultiRepoLandService extends fb303_core.BaseService {
  /// Fetch the latest content of a manifest file for a given bookmark.
  RepoFetchManifestContentResponse repo_fetch_manifest_content(
    1: RepoFetchManifestContentParams params,
  ) throws (
    1: source_control.RequestError request_error,
    2: source_control.InternalError internal_error,
  );

  /// Atomically modify bookmarks across multiple repos.
  MultipleRepoModifyBookmarksResponse multiple_repo_modify_bookmarks(
    1: MultipleRepoModifyBookmarksParams params,
  ) throws (
    1: source_control.RequestError request_error,
    2: source_control.InternalError internal_error,
    3: MultiRepoLandCasFailure cas_failure,
    4: MultiRepoLandRebaseConflict rebase_conflict,
    5: source_control.HookRejectionsException hook_rejections,
  );
}
