# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Verify that pushrebase merge resolution works correctly for multi-commit
# stacks where the conflicting file is modified by a non-HEAD commit.
#
# Regression test: the merge override must be applied to the commit that
# touches the conflicting file, not unconditionally to the stack HEAD.
# If applied to the wrong commit, the commit that actually touches the file
# keeps stale content, silently reverting concurrent server-side changes.

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

Create a base file with multiple lines and a second unrelated file
  $ hg up -q "min(all())"
  $ cat > shared.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > line5
  > line6
  > line7
  > line8
  > EOF
  $ echo "other content" > other.txt
  $ hg add shared.txt other.txt
  $ hg ci -m "add shared.txt and other.txt"
  $ hg push -r . --to master_bookmark -q

Server-side commit: modify the FIRST line of shared.txt
  $ hg up -q master_bookmark
  $ cat > shared.txt << 'EOF'
  > SERVER_EDIT_LINE1
  > line2
  > line3
  > line4
  > line5
  > line6
  > line7
  > line8
  > EOF
  $ hg ci -m "server: edit line 1"
  $ hg push -r . --to master_bookmark -q

Client 2-commit stack (from pre-server base):
Commit 1: modify the LAST line of shared.txt (non-overlapping with server)
Commit 2 (HEAD): modify other.txt only (does NOT touch shared.txt)
  $ hg up -q .~1
  $ cat > shared.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > line5
  > line6
  > line7
  > CLIENT_EDIT_LINE8
  > EOF
  $ hg ci -m "client commit 1: edit line 8 of shared.txt"
  $ echo "modified other content" > other.txt
  $ hg ci -m "client commit 2 (HEAD): edit other.txt only"

Pushrebase should succeed — merge resolution handles the conflict on shared.txt
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 2 commits for upload
  edenapi: queue * for upload (glob)
  edenapi: uploaded * (glob)
  edenapi: queue * trees for upload (glob)
  edenapi: uploaded * tree* (glob)
  edenapi: uploaded 2 changesets
  pushrebasing stack (*, *] (2 commits) to remote bookmark master_bookmark (glob)
  * files updated, 0 files merged, 0 files removed, 0 files unresolved (glob)
  updated remote bookmark master_bookmark to * (glob)

Verify the final HEAD has both server and client edits merged
  $ hg up -q master_bookmark
  $ cat shared.txt
  SERVER_EDIT_LINE1
  line2
  line3
  line4
  line5
  line6
  line7
  CLIENT_EDIT_LINE8

Verify other.txt was also updated correctly
  $ cat other.txt
  modified other content

BUG: The first rebased commit is missing the server edit (SERVER_EDIT_LINE1)
because the merge override was applied to HEAD instead of to this commit.
  $ hg up -q .^
  $ cat shared.txt
  line1
  line2
  line3
  line4
  line5
  line6
  line7
  CLIENT_EDIT_LINE8
