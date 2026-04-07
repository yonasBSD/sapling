#require no-eden

  $ enable amend commitcloud
  $ configure dummyssh
  $ setconfig commitcloud.hostname=testhost
  $ setconfig remotefilelog.reponame=server

  $ showgraph() {
  >    sl log -G -T "{desc}: {phase} {bookmarks} {remotenames}" -r "all()"
  > }

  $ newserver server
  $ cd $TESTTMP/server
  $ echo base > base
  $ sl commit -Aqm base
  $ sl bookmark base
  $ sl bookmark master
  $ setconfig infinitepush.server=yes infinitepush.reponame=testrepo
  $ setconfig infinitepush.indextype=disk infinitepush.storetype=disk

Set remotebookmarkssync True initially for the first repo and False for the second repo

  $ cd $TESTTMP
  $ clone server client1
  $ cd client1
  $ setconfig remotenames.selectivepulldefault=master,base
  $ setconfig commitcloud.remotebookmarkssync=True
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP
  $ sl pull -q
  $ showgraph
  @  base: public  remote/base remote/master
  $ cd $TESTTMP
  $ clone server client2
  $ cd client2
  $ setconfig remotenames.selectivepulldefault=master,base
  $ setconfig commitcloud.remotebookmarkssync=False
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP
  $ sl pull -q
  $ showgraph
  @  base: public  remote/base remote/master

Advance master
  $ cd $TESTTMP/server
  $ echo more >> base
  $ sl commit -Aqm public1

Pull in client1 (remote bookmarks sync enabled)
  $ cd $TESTTMP/client1
  $ sl pull -q
  $ sl cloud sync -q
  $ showgraph
  o  public1: public  remote/master
  │
  @  base: public  remote/base

Sync in client2 (remote bookmarks sync disabled). The master bookmark doesn't move
  $ cd $TESTTMP/client2
  $ sl cloud sync -q
  $ showgraph
  @  base: public  remote/base remote/master

Sync in client2 with sync enabled
  $ sl cloud sync -q --config commitcloud.remotebookmarkssync=true
  $ showgraph
  o  public1: public  remote/master
  │
  @  base: public  remote/base

Sync in client1 again.
  $ cd $TESTTMP/client1
  $ sl cloud sync -q
  $ showgraph
  o  public1: public  remote/master
  │
  @  base: public  remote/base

Sync in client2 again (remote bookmarks sync disabled)
  $ cd $TESTTMP/client2
  $ sl cloud sync -q
  $ showgraph
  o  public1: public  remote/master
  │
  @  base: public  remote/base

Advance master
  $ cd $TESTTMP/server
  $ echo more >> base
  $ sl commit -Aqm public2

Pull in client1 and sync
  $ cd $TESTTMP/client1
  $ sl pull -q
  $ sl cloud sync -q
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public  remote/base

Sync in client 2 with remotebookmarks sync enabled.
  $ cd $TESTTMP/client2
  $ sl cloud sync -q --config commitcloud.remotebookmarkssync=true
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public  remote/base

Delete the base bookmark on the server
  $ cd $TESTTMP/server
  $ sl book -d base

Pull in client 1, which removes the base remote bookmark
  $ cd $TESTTMP/client1
  $ sl pull -q
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public

Make an update to the cloud workspace in client 2 with remotebookmarks sync disabled
  $ cd $TESTTMP/client2
  $ sl book local1
  $ sl cloud sync -q
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public local1 remote/base

Sync in client1, deleted base bookmark remains deleted
  $ cd $TESTTMP/client1
  $ sl cloud sync -q
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public local1

Sync in client2 with remote bookmarks sync enabled.  The base bookmark
gets revived in the cloud workspace as this client didn't know that it
had been deleted on the server.
  $ cd $TESTTMP/client2
  $ sl cloud sync -q --config commitcloud.remotebookmarkssync=true
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public local1 remote/base
Pull in client 2, base bookmark is now deleted
  $ sl pull
  pulling from test:server

Sync again, and this time it gets deleted.
  $ sl cloud sync -q --config commitcloud.remotebookmarkssync=true
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public local1

And remains deleted in client 1
  $ cd $TESTTMP/client1
  $ sl cloud sync -q
  $ showgraph
  o  public2: public  remote/master
  │
  o  public1: public
  │
  @  base: public local1

