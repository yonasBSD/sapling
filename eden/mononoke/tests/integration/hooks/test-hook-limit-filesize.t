# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

  $ hook_test_setup \
  > limit_filesize <(
  >   cat <<CONF
  > bypass_commit_string="@allow-large-files"
  > config_int_lists={filesize_limits_values=[10]}
  > config_string_lists={filesize_limits_regexes=[".*"]}
  > CONF
  > )

Small file
  $ hg up -q "min(all())"
  $ echo 1 > 1
  $ hg ci -Aqm 1
  $ hg push -r . --to master_bookmark
  pushing rev 76fbeba29dc6 to destination mono:repo bookmark master_bookmark
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Large file
  $ LARGE_CONTENT=11111111111
  $ hg up -q "min(all())"
  $ echo "$LARGE_CONTENT" > largefile
  $ hg ci -Aqm largefile
  $ hg push -r . --to master_bookmark
  pushing rev bb0f06edf23b to destination mono:repo bookmark master_bookmark
  searching for changes
  remote: Command failed
  remote:   Error:
  remote:     hooks failed:
  remote:     limit_filesize for bb0f06edf23bed2fd049f1bd587dad41df09adc1: File size limit is 10 bytes. You tried to push file largefile that is over the limit (12 bytes, 1.20x the limit). This limit is enforced for files matching the following regex: ".*".
  remote: 
  remote:     WHY THIS IS BLOCKED: Large files have ongoing infrastructure costs — they impact caching systems, Mononoke, biggrep indexing, and permanent backups used by 30,000+ engineers.
  remote: 
  remote:     ALTERNATIVES TO CONSIDER:
  remote:     - Manifold: Store large binaries in blob storage
  remote:     - Dotslash: Distribute large tools without checking them in
  remote:     - Buckify: Package binaries as Buck-managed dependencies
  remote:     - LFS: Use Git LFS for large files that must be versioned
  remote:     - Split files: Break large files into smaller pieces
  remote: 
  remote:     IF ALTERNATIVES DO NOT WORK:
  remote:     1. Add @allow-large-files to your commit message (using `sl amend -e`).
  remote:     2. Request bypass approval at https://fburl.com/support/sourcecontrol.
  remote: 
  remote:     See https://fburl.com/landing_big_diffs for more details.
  abort: unexpected EOL, expected netstring digit
  [255]

Bypass
  $ hg commit --amend -m "@allow-large-files"
  $ hg push -r . --to master_bookmark
  pushing rev f85dc11d0c46 to destination mono:repo bookmark master_bookmark
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark
