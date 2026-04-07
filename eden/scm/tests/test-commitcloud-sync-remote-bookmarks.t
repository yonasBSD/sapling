#modern-config-incompatible

#require no-eden


  $ enable amend commitcloud
  $ configure dummyssh
  $ setconfig remotenames.autopullhoistpattern=re:.*
  $ setconfig commitcloud.hostname=testhost
  $ setconfig remotefilelog.reponame=server
  $ setconfig devel.segmented-changelog-rev-compat=true

  $ mkcommit() {
  >    echo $1 > $1
  >    sl add $1
  >    sl ci -m "$1"
  > }
  $ showgraph() {
  >    sl log -G -T "{desc}: {phase} {bookmarks} {remotenames}"
  > }

Setup remote repo
  $ sl init remoterepo
  $ cd remoterepo
  $ setconfig infinitepush.server=yes infinitepush.reponame=testrepo
  $ setconfig infinitepush.indextype=disk infinitepush.storetype=disk

  $ mkcommit root
  $ ROOT=$(sl log -r . -T{node})
  $ mkcommit c1 serv
  $ sl book warm
  $ sl up $ROOT -q
  $ mkcommit b1 serv
  $ sl book stable
  $ sl book main

  $ sl up $ROOT -q
  $ mkcommit a1 serv
  $ mkcommit a2 serv
  $ sl book master

  $ showgraph
  @  a2: draft master
  │
  o  a1: draft
  │
  │ o  b1: draft main stable
  ├─╯
  │ o  c1: draft warm
  ├─╯
  o  root: draft
  

Setup first client repo and subscribe to the bookmarks "stable" and "warm".
  $ cd ..
  $ setconfig remotenames.selectivepulldefault=master
  $ setconfig commitcloud.remotebookmarkssync=True

  $ sl clone -q ssh://user@dummy/remoterepo client1
  $ cd client1
  $ sl pull -B stable -B warm -q
  $ sl up 'desc(a2)' -q
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP
  $ sl cloud join -q
  $ showgraph
  o  b1: public  remote/stable
  │
  │ o  c1: public  remote/warm
  ├─╯
  │ @  a2: public  remote/master
  │ │
  │ o  a1: public
  ├─╯
  o  root: public
Setup the second client repo with enable remote bookmarks sync
The repo should be subscribed the "stable" and "warm" bookmark because the client1 was.
  $ cd ..
  $ sl clone -q ssh://user@dummy/remoterepo client2
  $ cd client2
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP
  $ sl cloud join -q
  $ showgraph
  o  b1: public  remote/stable
  │
  │ o  c1: public  remote/warm
  ├─╯
  │ @  a2: public  remote/master
  │ │
  │ o  a1: public
  ├─╯
  o  root: public

Setup third client repo but do not enable remote bookmarks sync
  $ cd ..
  $ sl clone -q ssh://user@dummy/remoterepo client3
  $ cd client3
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP
  $ setconfig commitcloud.remotebookmarkssync=False
  $ sl cloud join -q
  $ showgraph
  @  a2: public  remote/master
  │
  o  a1: public
  │
  o  root: public
  

Common case of unsynchronized remote bookmarks ("master")
  $ cd ../remoterepo
  $ mkcommit a3 serv
  $ cd ../client2
  $ sl pull -q
  $ sl up master -q
  $ mkcommit draft-1
  $ sl cloud sync -q
  $ showgraph
  @  draft-1: draft
  │
  │ o  b1: public  remote/stable
  │ │
  │ │ o  c1: public  remote/warm
  │ ├─╯
  o │  a3: public  remote/master
  │ │
  o │  a2: public
  │ │
  o │  a1: public
  ├─╯
  o  root: public

remote/master should point to the new commit
  $ cd ../client1
  $ sl cloud sync -q
  $ showgraph
  o  draft-1: draft
  │
  │ o  b1: public  remote/stable
  │ │
  │ │ o  c1: public  remote/warm
  │ ├─╯
  o │  a3: public  remote/master
  │ │
  @ │  a2: public
  │ │
  o │  a1: public
  ├─╯
  o  root: public
Subscribe to a new remote bookmark "main" that previously has been only known on the server
  $ cd ../client1
  $ sl pull -q
  $ sl pull -B main -q
  $ sl cloud sync -q
  $ showgraph
  o  draft-1: draft
  │
  │ o  b1: public  remote/main remote/stable
  │ │
  │ │ o  c1: public  remote/warm
  │ ├─╯
  o │  a3: public  remote/master
  │ │
  @ │  a2: public
  │ │
  o │  a1: public
  ├─╯
  o  root: public
  $ sl book --list-subscriptions
     remote/main               b2bfab231667
     remote/master             1b6e90080435
     remote/stable             b2bfab231667
     remote/warm               b8063fc7de93

the other client should be subscribed to this bookmark ("main") as well
  $ cd ../client2
  $ sl cloud sync -q
  $ showgraph
  @  draft-1: draft
  │
  │ o  b1: public  remote/main remote/stable
  │ │
  │ │ o  c1: public  remote/warm
  │ ├─╯
  o │  a3: public  remote/master
  │ │
  o │  a2: public
  │ │
  o │  a1: public
  ├─╯
  o  root: public
  $ sl book --list-subscriptions
     remote/main               b2bfab231667
     remote/master             1b6e90080435
     remote/stable             b2bfab231667
     remote/warm               b8063fc7de93

try to create a commit on top of the remote/stable
  $ cd ../client1
  $ sl up stable -q
  $ mkcommit draft-2
  $ sl cloud sync -q

  $ cd ../client2
  $ sl cloud sync -q
  $ showgraph
  o  draft-2: draft
  │
  │ @  draft-1: draft
  │ │
  o │  b1: public  remote/main remote/stable
  │ │
  │ │ o  c1: public  remote/warm
  ├───╯
  │ o  a3: public  remote/master
  │ │
  │ o  a2: public
  │ │
  │ o  a1: public
  ├─╯
  o  root: public
check that copy with disabled remote bookmarks sync doesn't affect the other copies
  $ cd ../client1
  $ sl up warm -q
  $ mkcommit draft-3
  $ sl cloud sync -q
  $ showgraph
  @  draft-3: draft
  │
  │ o  draft-2: draft
  │ │
  │ │ o  draft-1: draft
  │ │ │
  │ o │  b1: public  remote/main remote/stable
  │ │ │
  o │ │  c1: public  remote/warm
  ├─╯ │
  │   o  a3: public  remote/master
  │   │
  │   o  a2: public
  │   │
  │   o  a1: public
  ├───╯
  o  root: public
sync and create a new commit on top of the draft-3
  $ cd ../client3
  $ sl cloud sync -q
  $ sl up dc05efd94c6626ddd820e8d98b745ad6b50b82fc -q
  $ echo check >> check
  $ sl commit -qAm "draft-4"
  $ showgraph
  @  draft-4: draft
  │
  │ o  draft-3: draft
  │ │
  │ o  c1: draft
  │ │
  o │  draft-2: draft
  │ │
  o │  b1: draft
  ├─╯
  │ o  draft-1: draft
  │ │
  │ o  a3: draft
  │ │
  │ o  a2: public  remote/master
  │ │
  │ o  a1: public
  ├─╯
  o  root: public
  $ sl cloud sync -q

  $ cd ../client2
  $ sl cloud sync -q
  $ showgraph
  o  draft-4: draft
  │
  │ o  draft-3: draft
  │ │
  o │  draft-2: draft
  │ │
  │ │ @  draft-1: draft
  │ │ │
  o │ │  b1: public  remote/main remote/stable
  │ │ │
  │ o │  c1: public  remote/warm
  ├─╯ │
  │   o  a3: public  remote/master
  │   │
  │   o  a2: public
  │   │
  │   o  a1: public
  ├───╯
  o  root: public
