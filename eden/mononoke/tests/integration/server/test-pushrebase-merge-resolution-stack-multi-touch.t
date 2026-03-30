# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Verify that pushrebase merge resolution applies the override to the LAST
# commit in the stack that touches the conflicting file, even when multiple
# commits in the stack modify the same file.
#
# Also tests that overrides for different files are correctly routed to
# their respective last-touching commits.

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

Create base files
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
  $ cat > config.txt << 'EOF'
  > cfg1
  > cfg2
  > cfg3
  > cfg4
  > cfg5
  > cfg6
  > cfg7
  > cfg8
  > EOF
  $ hg add shared.txt config.txt
  $ hg ci -m "add shared.txt and config.txt"
  $ hg push -r . --to master_bookmark -q

Server-side: modify line 1 of shared.txt AND line 1 of config.txt
  $ hg up -q master_bookmark
  $ cat > shared.txt << 'EOF'
  > SERVER_LINE1
  > line2
  > line3
  > line4
  > line5
  > line6
  > line7
  > line8
  > EOF
  $ cat > config.txt << 'EOF'
  > SERVER_CFG1
  > cfg2
  > cfg3
  > cfg4
  > cfg5
  > cfg6
  > cfg7
  > cfg8
  > EOF
  $ hg ci -m "server: edit line 1 of shared.txt and config.txt"
  $ hg push -r . --to master_bookmark -q

Client 3-commit stack (from pre-server base):
Commit 1: modify shared.txt line 8 (non-overlapping with server)
Commit 2: modify config.txt line 8 (non-overlapping with server)
Commit 3 (HEAD): modify shared.txt AGAIN at line 5 (non-overlapping)
The merge override for shared.txt should go to commit 3 (last toucher)
The merge override for config.txt should go to commit 2 (last toucher)
  $ hg up -q .~1
  $ cat > shared.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > line5
  > line6
  > line7
  > CLIENT_LINE8
  > EOF
  $ hg ci -m "client commit 1: edit shared.txt line 8"
  $ cat > config.txt << 'EOF'
  > cfg1
  > cfg2
  > cfg3
  > cfg4
  > cfg5
  > cfg6
  > cfg7
  > CLIENT_CFG8
  > EOF
  $ hg ci -m "client commit 2: edit config.txt line 8"
  $ cat > shared.txt << 'EOF'
  > line1
  > line2
  > line3
  > line4
  > CLIENT_LINE5
  > line6
  > line7
  > CLIENT_LINE8
  > EOF
  $ hg ci -m "client commit 3 (HEAD): edit shared.txt line 5"

Pushrebase should succeed with merge resolution
  $ hg push -r . --to master_bookmark
  pushing rev * to destination https://localhost:$LOCAL_PORT/edenapi/ bookmark master_bookmark (glob)
  edenapi: queue 3 commits for upload
  edenapi: queue * for upload (glob)
  edenapi: uploaded * (glob)
  edenapi: queue * trees for upload (glob)
  edenapi: uploaded * tree* (glob)
  edenapi: uploaded 3 changesets
  pushrebasing stack (*, *] (3 commits) to remote bookmark master_bookmark (glob)
  * files updated, 0 files merged, 0 files removed, 0 files unresolved (glob)
  updated remote bookmark master_bookmark to * (glob)

Verify HEAD has all edits merged for both files
  $ hg up -q master_bookmark
  $ cat shared.txt
  SERVER_LINE1
  line2
  line3
  line4
  CLIENT_LINE5
  line6
  line7
  CLIENT_LINE8
  $ cat config.txt
  SERVER_CFG1
  cfg2
  cfg3
  cfg4
  cfg5
  cfg6
  cfg7
  CLIENT_CFG8

Verify commit 2 (.^) has shared.txt from rebased C1 (SERVER_LINE1 merged,
but CLIENT_LINE5 is NOT present yet — C2 does not touch shared.txt)
  $ hg up -q .^
  $ cat shared.txt
  SERVER_LINE1
  line2
  line3
  line4
  line5
  line6
  line7
  CLIENT_LINE8

Verify commit 2 has merged config.txt (C2 touches config.txt, so the
cascading merge applies the server override here)
  $ cat config.txt
  SERVER_CFG1
  cfg2
  cfg3
  cfg4
  cfg5
  cfg6
  cfg7
  CLIENT_CFG8

Verify commit 1 (.^^) has merged shared.txt (C1 touches shared.txt)
  $ hg up -q .^
  $ cat shared.txt
  SERVER_LINE1
  line2
  line3
  line4
  line5
  line6
  line7
  CLIENT_LINE8

Verify commit 1 does NOT have CLIENT_CFG8 in config.txt (C1 does not
touch config.txt, so it inherits the server's version)
  $ cat config.txt
  SERVER_CFG1
  cfg2
  cfg3
  cfg4
  cfg5
  cfg6
  cfg7
  cfg8
