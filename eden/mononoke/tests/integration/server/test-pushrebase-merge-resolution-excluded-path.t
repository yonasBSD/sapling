# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Verify that merge_resolution_excluded_path_prefixes skips merge resolution
# for files under the excluded prefix while still merging other files.
#
# With merge resolution enabled and "excluded_dir" in the excluded prefixes:
# - A non-overlapping conflict on "excluded_dir/file.txt" should be REJECTED
#   (merge resolution skipped for that prefix)
# - A non-overlapping conflict on "allowed_dir/file.txt" should SUCCEED
#   (merge resolution applies normally)

  $ . "${TEST_FIXTURES}/library.sh"
  $ setconfig push.edenapi=true

  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:pushrebase_enable_merge_resolution": true,
  >     "scm/mononoke:pushrebase_merge_resolution_derive_fsnodes": true
  >   },
  >   "ints": {
  >     "scm/mononoke:pushrebase_max_merge_conflicts": 10,
  >     "scm/mononoke:pushrebase_max_merge_file_size": 10485760
  >   }
  > }
  > EOF

Set up config with excluded path prefix, then start server
  $ BLOB_TYPE="blob_files" setup_common_config "blob_files"
  $ cd "$TESTTMP/mononoke-config" || exit 1
  $ sed -i '/^\[pushrebase\]/a merge_resolution_excluded_path_prefixes=["excluded_dir"]' repos/repo/server.toml
  $ cd "$TESTTMP" || exit 1

  $ testtool_drawdag -R repo --derive-all <<EOF
  > C
  > |
  > B
  > |
  > A
  > # bookmark: C master_bookmark
  > EOF
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

  $ start_and_wait_for_mononoke_server
  $ hg clone -q "mono:repo" repo --noupdate
  $ cd repo || exit 1
  $ cat >> .hg/hgrc <<EOF
  > [ui]
  > ssh ="$DUMMYSSH"
  > [extensions]
  > amend =
  > pushrebase =
  > EOF

--- Test 1: File under excluded prefix should be REJECTED ---

Create a base file under excluded_dir/
  $ hg up -q "min(all())"
  $ mkdir -p excluded_dir
  $ cat > excluded_dir/file.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > line5
  > EOF
  $ hg add excluded_dir/file.txt
  $ hg ci -m "add excluded_dir/file.txt"
  $ hg push -r . --to master_bookmark -q

Server edits line 1
  $ hg up -q master_bookmark
  $ cat > excluded_dir/file.txt << 'EOF'
  > SERVER_EDIT_LINE1
  > line2
  > line3
  > line4
  > line5
  > EOF
  $ hg ci -m "server: edit excluded_dir line 1"
  $ hg push -r . --to master_bookmark -q

Client edits line 5 (non-overlapping — would merge if not excluded)
  $ hg up -q .~1
  $ cat > excluded_dir/file.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > CLIENT_EDIT_LINE5
  > EOF
  $ hg ci -m "client: edit excluded_dir line 5"

Pushrebase should FAIL — file is under excluded prefix
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue * for upload (glob)
  edenapi: uploaded * (glob)
  edenapi: queue * trees for upload (glob)
  edenapi: uploaded * tree* (glob)
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  abort: Server error: Conflicts while pushrebasing: [PushrebaseConflict { left: MPath("excluded_dir/file.txt"), right: MPath("excluded_dir/file.txt") }]
  [255]

--- Test 2: File NOT under excluded prefix should SUCCEED ---

Create a base file under allowed_dir/
  $ hg up -q master_bookmark
  $ mkdir -p allowed_dir
  $ cat > allowed_dir/file.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > line5
  > EOF
  $ hg add allowed_dir/file.txt
  $ hg ci -m "add allowed_dir/file.txt"
  $ hg push -r . --to master_bookmark -q

Server edits line 1
  $ hg up -q master_bookmark
  $ cat > allowed_dir/file.txt << 'EOF'
  > SERVER_EDIT_LINE1
  > line2
  > line3
  > line4
  > line5
  > EOF
  $ hg ci -m "server: edit allowed_dir line 1"
  $ hg push -r . --to master_bookmark -q

Client edits line 5 (non-overlapping — should merge normally)
  $ hg up -q .~1
  $ cat > allowed_dir/file.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > CLIENT_EDIT_LINE5
  > EOF
  $ hg ci -m "client: edit allowed_dir line 5"

Pushrebase should SUCCEED — merge resolution applies to non-excluded paths
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue * (glob)
  edenapi: queue * (glob)
  edenapi: uploaded * (glob)
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  * files updated, 0 files merged, 0 files removed, 0 files unresolved (glob)
  updated remote bookmark master_bookmark to * (glob)

Verify the merged file has BOTH edits
  $ hg up -q master_bookmark
  $ cat allowed_dir/file.txt
  SERVER_EDIT_LINE1
  line2
  line3
  line4
  CLIENT_EDIT_LINE5
