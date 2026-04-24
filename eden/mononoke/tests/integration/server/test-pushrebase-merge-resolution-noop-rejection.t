# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Demonstrates the no-op merge commit bug: when a client pushes a commit
# whose file content is identical to what already exists in trunk for a
# conflicting path, merge resolution trivially succeeds (local == other)
# and the commit lands as a no-op instead of being rejected.
#
# Pre-merge-resolution this push would have been rejected as a path
# conflict. With merge resolution enabled it silently lands an empty
# commit.
#
# FIXME: The assertions below describe the current BUGGY behavior — the
# duplicate-content push succeeds and a no-op commit lands. The follow-up
# diff (D-TBD) adds detection + a JustKnob-gated rejection that restores
# the pre-merge-resolution behavior, and flips these assertions.

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

Client commit (from pre-server base): IDENTICAL edit to line 2
This is the bug trigger: client and server both wrote the same content.
  $ hg up -q .~1
  $ cat > shared.txt << 'EOF'
  > line1
  > SHARED_EDIT
  > line3
  > EOF
  $ hg ci -m "client: identical edit to line 2"

# FIXME: With the fix in place, this push will be REJECTED with
# `abort: Server error: Conflicts while pushrebasing: [PushrebaseConflict ...]`
# matching the pre-merge-resolution behavior. The current buggy behavior is
# that the push succeeds and a no-op commit lands. Note the "0 trees for
# upload" and "0 files updated" lines below — concrete evidence that the
# rebased commit produces no real change.
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue * for upload (glob)
  edenapi: queue 0 trees for upload
  edenapi: uploaded * (glob)
  pushrebasing stack (*, *] (1 commit) to remote bookmark master_bookmark (glob)
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  updated remote bookmark master_bookmark to * (glob)

# FIXME: After the fix, master_bookmark stays at "server: edit line 2"
# because the client's duplicate-content push is rejected. Currently
# master_bookmark advances to the no-op client commit.
  $ hg up -q master_bookmark
  $ hg log -r master_bookmark -T '{desc}\n'
  client: identical edit to line 2

The file content is unchanged from the server's edit (since the client wrote
identical content). This is what makes it a no-op commit — the rebased
changeset writes content that already matches its parent.
  $ cat shared.txt
  line1
  SHARED_EDIT
  line3
