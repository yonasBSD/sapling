#if osx
#require security no-eden
#else
#require no-eden
#endif
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ configure dummyssh
  $ enable commitcloud

  $ cat >> $HGRCPATH << EOF
  > [commitcloud]
  > hostname = testhost
  > servicetype = local
  > servicelocation = $TESTTMP
  > EOF

  $ setconfig 'remotefilelog.reponame=server'
  $ sl init server
  $ cd server
  $ cat >> .sl/config << 'EOF'
  > [infinitepush]
  > server = yes
  > indextype = disk
  > storetype = disk
  > reponame = testrepo
  > EOF

  $ sl clone 'ssh://user@dummy/server' client -q
  $ cd client

  $ cat >> $TESTTMP/workspacesdata << 'EOF'
  > { "workspaces_data" : { "workspaces": [ { "name": "user/test/old", "archived": true, "version": 0 }, { "name": "user/test/default", "archived": false, "version": 0 }  ] } }
  > EOF

  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace
  run `sl cloud list --all` to list all workspaces, including deleted


  $ sl cloud list --all
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
          old (archived)
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace


  $ sl cloud delete -w default
  commitcloud: workspace user/test/default has been deleted


  $ sl cloud delete -w default_abc
  abort: unknown workspace: user/test/default_abc
  [255]


  $ sl cloud list --all
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          old (archived)
          default (archived)
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace


  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  no active workspaces found with the prefix user/test/


  $ sl cloud undelete -w default
  commitcloud: workspace user/test/default has been restored


  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace
  run `sl cloud list --all` to list all workspaces, including deleted


  $ sl cloud undelete -w old
  commitcloud: workspace user/test/old has been restored


  $ sl cloud list
  commitcloud: searching workspaces for the 'server' repo
  the following commitcloud workspaces are available:
          default
          old
  run `sl cloud sl -w <workspace name>` to view the commits
  run `sl cloud switch -w <workspace name>` to switch to a different workspace

