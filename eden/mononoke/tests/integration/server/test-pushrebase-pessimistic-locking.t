# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test pessimistic per-bookmark locking for pushrebase.
# When enabled, pushrebase acquires a SQL-level per-bookmark lock before
# rebasing, eliminating wasted work from CAS retry races. The lock
# guarantees only one writer per bookmark at a time; CAS is retained as
# defense-in-depth.

  $ . "${TEST_FIXTURES}/library.sh"
  $ setconfig push.edenapi=true

Enable per-bookmark locking + pessimistic mode for master_bookmark
  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:per_bookmark_locking": true
  >   }
  > }
  > EOF

  $ PUSHREBASE_PESSIMISTIC_LOCKING_BOOKMARKS="master_bookmark" BLOB_TYPE="blob_files" default_setup_drawdag
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

-- Test 1: Pushrebase to master_bookmark via pessimistic path
  $ hg up -q "min(all())"
  $ echo 1 > 1 && hg add 1 && hg ci -m "pessimistic push to master"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark master_bookmark to * (glob)

-- Test 2: Conflicting push to master (pessimistic path, conflict detected)
  $ hg up -q "min(all())"
  $ echo "first change" > A && hg ci -m "modify A on master first"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark master_bookmark to * (glob)

  $ hg up -q "min(all())"
  $ echo "conflicting change" > A && hg ci -m "conflicting modify A"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  abort: Server error: Conflicts while pushrebasing: * (glob)
  [255]

-- Verify bookmark advanced correctly
  $ mononoke_admin bookmarks -R repo get master_bookmark
  * (glob)
