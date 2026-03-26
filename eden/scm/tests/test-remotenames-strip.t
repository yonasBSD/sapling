#modern-config-incompatible

#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.


# Test that sl debugstrip -B stops at remotenames

  $ export HGIDENTITY=sl
  $ sl init server
  $ sl clone -q server client
  $ cd client
  $ echo x > x
  $ sl commit -Aqm a
  $ echo a > a
  $ sl commit -Aqm aa
  $ sl debugmakepublic
  $ sl push -q --to master --create
  $ echo b > b
  $ sl commit -Aqm bb
  $ sl book foo
  $ sl log -T '{desc} ({bookmarks}) ({remotebookmarks})\n'
  bb (foo) ()
  aa () (public/a6e72781733c178cd290a07022bb6c8460749e7b remote/master)
  a () ()
  $ sl debugstrip -qB foo
  bookmark 'foo' deleted
  $ sl log -T '{desc} ({bookmarks}) ({remotebookmarks})\n'
  aa () (public/a6e72781733c178cd290a07022bb6c8460749e7b remote/master)
  a () ()

# Test that sl debugstrip -B deletes bookmark even if there is a remote bookmark,
# but doesn't delete the commit.

  $ sl init server
  $ sl clone -q server client
  $ cd client
  $ echo x > x
  $ sl commit -Aqm a
  $ sl debugmakepublic
  $ sl push -q --to master --create
  $ sl book foo
  $ sl log -T '{desc} ({bookmarks}) ({remotebookmarks})\n'
  a (foo) (public/770eb8fce608e2c55f853a8a5ea328b659d70616 remote/master)
  $ sl debugstrip -qB foo
  bookmark 'foo' deleted
  abort: empty revision set
  [255]
  $ sl log -T '{desc} ({bookmarks}) ({remotebookmarks})\n'
  a () (public/770eb8fce608e2c55f853a8a5ea328b659d70616 remote/master)
