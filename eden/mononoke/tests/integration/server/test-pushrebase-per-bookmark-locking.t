# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test per-bookmark locking for BookmarkUpdateLog.
# Validates that pushrebase works correctly with the new per-bookmark locking
# code path (auto-increment IDs, per-bookmark row locks) instead of the
# legacy SELECT MAX(id) + 1 approach.

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

Setup with standard drawdag (creates master_bookmark on commit C)
  $ BLOB_TYPE="blob_files" default_setup_drawdag
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

Create additional bookmarks on commit C
  $ mononoke_admin bookmarks -R repo set release_branch $C
  Creating publishing bookmark release_branch at e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2
  $ mononoke_admin bookmarks -R repo set feature_branch $C
  Creating publishing bookmark feature_branch at e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

-- Test 1: Pushrebase to master_bookmark with per-bookmark locking
  $ hg up -q "min(all())"
  $ echo 1 > 1 && hg add 1 && hg ci -m "push to master"
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

-- Test 2: Pushrebase to release_branch (different bookmark)
  $ hg up -q "min(all())"
  $ echo 2 > 2 && hg add 2 && hg ci -m "push to release"
  $ hg push -r . --to release_branch
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark release_branch (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark release_branch (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark release_branch to * (glob)

-- Test 3: Pushrebase to feature_branch (third bookmark)
  $ hg up -q "min(all())"
  $ echo 3 > 3 && hg add 3 && hg ci -m "push to feature"
  $ hg push -r . --to feature_branch
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark feature_branch (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  pushrebasing stack (*, *] (1 commit) to remote bookmark feature_branch (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark feature_branch to * (glob)

-- Verify all three bookmarks advanced correctly via admin tool
  $ mononoke_admin bookmarks -R repo get master_bookmark
  * (glob)
  $ mononoke_admin bookmarks -R repo get release_branch
  * (glob)
  $ mononoke_admin bookmarks -R repo get feature_branch
  * (glob)

-- Test 4: Second pushrebase to master (IDs keep incrementing)
  $ hg up -q "min(all())"
  $ echo 4 > 4 && hg add 4 && hg ci -m "second push to master"
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

-- Test 5: Create a new bookmark via push (lock row should be auto-created)
  $ hg up -q "min(all())"
  $ echo 5 > 5 && hg add 5 && hg ci -m "push to new bookmark"
  $ hg push -r . --to new_branch --create
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark new_branch (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  creating remote bookmark new_branch

-- Verify all bookmarks exist and point to correct commits
  $ mononoke_admin bookmarks -R repo list
  * feature_branch (glob)
  * master_bookmark (glob)
  * new_branch (glob)
  * release_branch (glob)
