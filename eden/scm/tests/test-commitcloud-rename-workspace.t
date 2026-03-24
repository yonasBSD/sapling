#require no-eden

  $ export HGIDENTITY=sl
  $ enable smartlog
  $ showgraph() {
  >    sl log -G -T "{desc}: {phase} {bookmarks} {remotenames}" -r "all()"
  > }

  $ mkcommit() {
  >   echo "$1" > "$1"
  >   sl commit -Aqm "$1"
  > }

  $ newserver server
  $ cd $TESTTMP/server

  $ mkcommit "base"
  $ sl bookmark master
  $ cd ..

Make the first clone of the server
  $ clone server client1
  $ cd client1
  $ sl cloud rename -d w1 # renaming of the default one should fail
  abort: rename of the default workspace is not allowed
  [255]
  $ sl cloud leave -q
  $ sl cloud join -w w1
  commitcloud: this repository is now connected to the 'user/test/w1' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/test/w1'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)

  $ cd ..

Make the second clone of the server
  $ clone server client2
  $ cd client2
  $ mkcommit "A (W2)"
  $ mkcommit "B (W2)"
  $ sl cloud leave -q
  $ sl cloud join -w w2
  commitcloud: this repository is now connected to the 'user/test/w2' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/test/w2'
  commitcloud: head '67590a46a20b' hasn't been uploaded yet
  edenapi: queue 2 commits for upload
  edenapi: queue 2 files for upload
  edenapi: uploaded 2 files
  edenapi: queue 2 trees for upload
  edenapi: uploaded 2 trees
  edenapi: uploaded 2 changesets
  commitcloud: commits synchronized
  finished in * (glob)

  $ cd ..

Make a commit in the first client, and sync it
  $ cd client1
  $ mkcommit "A (W1)"
  $ mkcommit "B (W1)"
  $ sl cloud sync -q

  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
          w2
          w1 (connected)
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace

Rename to the existing workspace should fail 
  $ sl cloud rename -d w2
  commitcloud: synchronizing 'server' with 'user/test/w1'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)
  commitcloud: rename the 'user/test/w1' workspace to 'user/test/w2' for the repo 'server'
  abort: workspace: 'user/test/w2' already exists
  [255]


Rename to a new name should work
Smartlog and status should stay the same
  $ sl cloud rename -d w3
  commitcloud: synchronizing 'server' with 'user/test/w1'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)
  commitcloud: rename the 'user/test/w1' workspace to 'user/test/w3' for the repo 'server'
  commitcloud: rename successful

  $ showgraph
  @  B (W1): draft
  │
  o  A (W1): draft
  │
  o  base: public  remote/master
  
  $ sl cloud sync --debug
  commitcloud: synchronizing 'server' with 'user/test/w3'
  commitcloud: nothing to upload
  commitcloud local service: get_references for current version 2
  commitcloud: commits synchronized
  finished in * (glob)

Rename workspace that is not a current one
  $ sl cloud rename -s w2 -d w4
  commitcloud: rename the 'user/test/w2' workspace to 'user/test/w4' for the repo 'server'
  commitcloud: rename successful

  $ cd ..

Move to the second client
`sl cloud sync` should be broken
  $ cd client2
  $ sl cloud sync
  commitcloud: synchronizing 'server' with 'user/test/w2'
  commitcloud: nothing to upload
  abort: 'get_references' failed, the workspace has been renamed or client has an invalid state
  [255]
  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
          w3
          w4
          w2 (connected) (renamed or removed)
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace

  $ sl cloud status
  Workspace: w2 (renamed or removed) (run `sl cloud list` and switch to a different one)
  Raw Workspace Name: user/test/w2
  Automatic Sync (on local changes): OFF
  Automatic Sync via 'Scm Daemon' (on remote changes): OFF
  Last Sync Version: 1
  Last Sync Heads: 1 (0 omitted)
  Last Sync Bookmarks: 0 (0 omitted)
  Last Sync Remote Bookmarks: 1
  Last Sync Time: * (glob)
  Last Sync Status: Exception:
  'get_references' failed, the workspace has been renamed or client has an invalid state

  $ sl cloud switch -w w4 --force
  commitcloud: now this repository will be switched from the 'user/test/w2' to the 'user/test/w4' workspace
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  working directory now at d20a80d4def3
  commitcloud: this repository is now connected to the 'user/test/w4' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/test/w4'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)

  $ showgraph
  o  B (W2): draft
  │
  o  A (W2): draft
  │
  @  base: public  remote/master
  

  $ sl cloud rename --rehost -d testhost
  abort: 'rehost' option and 'destination' option are incompatible
  [255]
  $ sl cloud rename --rehost
  commitcloud: synchronizing 'server' with 'user/test/w4'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)
  commitcloud: rename the 'user/test/w4' workspace to 'user/test/testhost' for the repo 'server'
  commitcloud: rename successful

  $ cd ..

Back to client1  

  $ cd client1
  $ sl up master
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl cloud switch -w testhost # switch to a renamed workspace should work
  commitcloud: synchronizing 'server' with 'user/test/w3'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)
  commitcloud: now this repository will be switched from the 'user/test/w3' to the 'user/test/testhost' workspace
  commitcloud: this repository is now connected to the 'user/test/testhost' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/test/testhost'
  commitcloud: nothing to upload
  pulling 67590a46a20b from test:server
  searching for changes
  commitcloud: commits synchronized
  finished in * (glob)

  $ showgraph
  o  B (W2): draft
  │
  o  A (W2): draft
  │
  @  base: public  remote/master
  
 
Try to rename an unknown workspace
  $ sl cloud rename -s abc -d w5
  commitcloud: rename the 'user/test/abc' workspace to 'user/test/w5' for the repo 'server'
  abort: unknown workspace: user/test/abc
  [255]

Try to rename a workspace after leave
  $ sl cloud leave
  commitcloud: this repository is now disconnected from the 'user/test/testhost' workspace
  $ sl cloud rename -d w5
  abort: the repo is not connected to any workspace, please provide the source workspace
  [255]
  $ sl cloud join -w testhost
  commitcloud: this repository is now connected to the 'user/test/testhost' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/test/testhost'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)

Test reclaim workspace
  $ sl cloud reclaim
  abort: please, provide '--user' option, can not identify the former username from the current workspace
  [255]

  $ sl cloud reclaim --user test
  commitcloud: nothing to reclaim: triggered for the same username
  [1]

  $ unset HGUSER
  $ setconfig ui.username='Jane Doe <jdoe@example.com>'

  $ sl smartlog -T '{desc}\n'
  o  B (W2)
  │
  o  A (W2)
  │
  @  base
  
  note: background backup is currently disabled so your commits are not being backed up.
  hint[commitcloud-username-migration]: username configuration has been changed
  please, run `sl cloud reclaim` to migrate your commit cloud workspaces
  hint[hint-ack]: use 'sl hint --ack commitcloud-username-migration' to silence these hints

  $ sl cloud reclaim
  commitcloud: the following active workspaces are reclaim candidates:
      default
      w3
      testhost
  commitcloud: reclaim of active workspaces completed

  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
          w3
          testhost (connected)
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace

  $ sl cloud status
  Workspace: testhost
  Raw Workspace Name: user/jdoe@example.com/testhost
  Automatic Sync (on local changes): OFF
  Automatic Sync via 'Scm Daemon' (on remote changes): OFF
  Last Sync Version: 1
  Last Sync Heads: 1 (0 omitted)
  Last Sync Bookmarks: 0 (0 omitted)
  Last Sync Remote Bookmarks: 1
  Last Sync Time: * (glob)
  Last Sync Status: Success

Check that sync is ok after the reclaim
  $ sl cloud sync
  commitcloud: synchronizing 'server' with 'user/jdoe@example.com/testhost'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)

Reclaim again
  $ setconfig ui.username='Jane Doe <janedoe@example.com>'
  $ sl cloud reclaim --user 'jdoe@example.com'
  commitcloud: the following active workspaces are reclaim candidates:
      default
      w3
      testhost
  commitcloud: reclaim of active workspaces completed

  $ sl cloud delete -w w3
  commitcloud: workspace user/janedoe@example.com/w3 has been deleted
  $ sl cloud delete -w testhost
  commitcloud: workspace user/janedoe@example.com/testhost has been deleted

  $ setconfig ui.username='Jane Doe <jdoe@example.com>'
  $ sl cloud reclaim 
  commitcloud: the following active workspaces are reclaim candidates:
      default
  commitcloud: reclaim of active workspaces completed
  commitcloud: the following archived workspaces are reclaim candidates:
      w3
      testhost
  commitcloud: reclaim of archived workspaces completed

Try to reclaim after cloud leave
  $ sl cloud leave
  commitcloud: this repository is now disconnected from the 'user/jdoe@example.com/testhost' workspace
  $ setconfig ui.username='Jane Doe <janedoe@example.com>'
  $ sl cloud reclaim
  abort: please, provide '--user' option, can not identify the former username from the current workspace
  [255]

  $ sl cloud join
  commitcloud: this repository is now connected to the 'user/janedoe@example.com/default' workspace for the 'server' repo
  commitcloud: synchronizing 'server' with 'user/janedoe@example.com/default'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * (glob)
