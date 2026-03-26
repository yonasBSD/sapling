# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test per-bookmark locking shadow mode.
# Validates that shadow mode logs bookmark count without changing behavior.
# The old SELECT MAX(id) path is still used, but shadow mode logs the
# number of bookmarks that would be locked under the new path.

  $ . "${TEST_FIXTURES}/library.sh"
  $ setconfig push.edenapi=true

Enable shadow mode (NOT the active per-bookmark locking path)
  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:per_bookmark_locking": false,
  >     "scm/mononoke:per_bookmark_locking_shadow": true
  >   }
  > }
  > EOF

  $ BLOB_TYPE="blob_files" default_setup_drawdag --scuba-log-file "$TESTTMP/scuba.json"
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

-- Push to master_bookmark with shadow mode enabled
  $ hg up -q "min(all())"
  $ echo 1 > 1 && hg add 1 && hg ci -m "shadow mode push"
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

-- Verify shadow mode logged the bookmark count to scuba
  $ grep "per_bookmark_locking_shadow" "$TESTTMP/scuba.json" | jq -r '.int.per_bookmark_lock_bookmark_count'
  1
