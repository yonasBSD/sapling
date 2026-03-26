# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test per-bookmark locking with pushrebase conflicts.
# Validates that conflict detection works correctly with the new
# per-bookmark locking code path — a conflict on one bookmark should
# not affect pushes to other bookmarks.

  $ . "${TEST_FIXTURES}/library.sh"
  $ setconfig push.edenapi=true

Enable per-bookmark locking via JustKnob
  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:per_bookmark_locking": true
  >   }
  > }
  > EOF

  $ BLOB_TYPE="blob_files" default_setup_drawdag
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

Create a second bookmark
  $ mononoke_admin bookmarks -R repo set other_branch $C
  Creating publishing bookmark other_branch at e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

-- First, push something to master that modifies file "A"
  $ hg up -q "min(all())"
  $ echo "first change" > A && hg ci -m "modify A on master"
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

-- Now try to push a conflicting change to the same file on master
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

-- Push to other_branch should still work (independent bookmark)
  $ hg up -q "min(all())"
  $ echo "other branch" > other && hg add other && hg ci -m "push to other branch"
  $ hg push -r . --to other_branch
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark other_branch (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark other_branch (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark other_branch to * (glob)

-- Non-conflicting push to master should also still work
  $ hg up -q "min(all())"
  $ echo "no conflict" > noconflict && hg add noconflict && hg ci -m "non-conflicting push to master"
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
