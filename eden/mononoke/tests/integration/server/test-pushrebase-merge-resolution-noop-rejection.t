# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Verify that pushrebase rejects pushes whose every file_change becomes a
# no-op due to merge resolution.
#
# Bug: with merge resolution enabled, a client commit whose file content is
# identical to what already exists in trunk for a conflicting path
# (`local_content_id == other_id`) was being landed as a no-op commit
# instead of being rejected as a path conflict.
#
# Fix: when `pushrebase_reject_noop_merge_commits` is enabled, detect this
# case and reject the entire stack with a Conflicts error matching the
# pre-merge-resolution behavior.

  $ . "${TEST_FIXTURES}/library.sh"
  $ setconfig push.edenapi=true

  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:pushrebase_enable_merge_resolution": true,
  >     "scm/mononoke:pushrebase_merge_resolution_derive_fsnodes": true,
  >     "scm/mononoke:pushrebase_reject_noop_merge_commits": true
  >   },
  >   "ints": {
  >     "scm/mononoke:pushrebase_max_merge_conflicts": 10,
  >     "scm/mononoke:pushrebase_max_merge_file_size": 10485760
  >   }
  > }
  > EOF

  $ BLOB_TYPE="blob_files" default_setup_drawdag
  A=aa53d24251ff3f54b1b2c29ae02826701b2abeb0079f1bb13b8434b54cd87675
  B=f8c75e41a0c4d29281df765f39de47bca1dcadfdc55ada4ccc2f6df567201658
  C=e32a1e342cdb1e38e88466b4c1a01ae9f410024017aa21dc0a1c5da6b3963bf2

Create a base file
  $ hg up -q "min(all())"
  $ cat > shared.txt << 'EOF'
  > line1
  > line2
  > line3
  > EOF
  $ hg add shared.txt
  $ hg ci -m "add shared.txt"
  $ hg push -r . --to master_bookmark -q

Server-side commit: replace line 2 with SHARED_EDIT
  $ hg up -q master_bookmark
  $ cat > shared.txt << 'EOF'
  > line1
  > SHARED_EDIT
  > line3
  > EOF
  $ hg ci -m "server: edit line 2"
  $ hg push -r . --to master_bookmark -q

Client commit (from pre-server base): IDENTICAL edit to line 2.
This triggers the bug: client and server both wrote the same content.
  $ hg up -q .~1
  $ cat > shared.txt << 'EOF'
  > line1
  > SHARED_EDIT
  > line3
  > EOF
  $ hg ci -m "client: identical edit to line 2"

Pushrebase should be REJECTED with a Conflicts error naming shared.txt,
matching the pre-merge-resolution behavior.
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue * for upload (glob)
  edenapi: queue 0 trees for upload
  edenapi: uploaded * (glob)
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  abort: Server error: Conflicts while pushrebasing: [PushrebaseConflict { left: MPath("shared.txt"), right: MPath("shared.txt") }]
  [255]

Confirm master_bookmark did NOT advance — the duplicate-content push was rejected.
  $ hg pull -q
  $ hg log -r master_bookmark -T '{desc}\n'
  server: edit line 2
