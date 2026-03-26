# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test per-bookmark locking with stack pushrebase (multiple commits in one push).
# Validates that pushing a stack of commits works correctly with per-bookmark
# locking and auto-increment ID allocation.

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

-- Push a stack of 3 commits to master_bookmark
  $ hg up -q "min(all())"
  $ echo 1 > 1 && hg add 1 && hg ci -m "stack commit 1"
  $ echo 2 > 2 && hg add 2 && hg ci -m "stack commit 2"
  $ echo 3 > 3 && hg add 3 && hg ci -m "stack commit 3"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 3 commits for upload
  edenapi: queue 3 files for upload
  edenapi: uploaded 3 files
  edenapi: queue 3 trees for upload
  edenapi: uploaded 3 trees
  edenapi: uploaded 3 changesets
  pushrebasing stack (*, *] (3 commits) to remote bookmark master_bookmark (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark master_bookmark to * (glob)

-- Verify all 3 commits are visible
  $ hg pull -q
  $ log -r "all()"
  @  stack commit 3 [public;rev=*;*] remote/master_bookmark (glob)
  │
  o  stack commit 2 [public;rev=*;*] (glob)
  │
  o  stack commit 1 [public;rev=*;*] (glob)
  │
  o  C [public;rev=*;*] (glob)
  │
  o  B [public;rev=*;*] (glob)
  │
  o  A [public;rev=*;*] (glob)
  $

-- Push another stack to a different bookmark
  $ mononoke_admin bookmarks -R repo set release $C
  Creating publishing bookmark release at e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2
  $ hg up -q "min(all())"
  $ echo 4 > 4 && hg add 4 && hg ci -m "release commit 1"
  $ echo 5 > 5 && hg add 5 && hg ci -m "release commit 2"
  $ hg push -r . --to release
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark release (glob)
  edenapi: queue 2 commits for upload
  edenapi: queue 2 files for upload
  edenapi: uploaded 2 files
  edenapi: queue 2 trees for upload
  edenapi: uploaded 2 trees
  edenapi: uploaded 2 changesets
  pushrebasing stack (*, *] (2 commits) to remote bookmark release (glob)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark release to * (glob)
