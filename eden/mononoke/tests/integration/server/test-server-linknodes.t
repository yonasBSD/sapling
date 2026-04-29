# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

define an extension that reveals when Mercurial is fixing up linkrevs

  $ cat > $TESTTMP/loglinkrevfixup.py <<EOF
  > def uisetup(ui):
  >     class loglinkrevfixup(ui.__class__):
  >         def log(self, event, *msg, **opts):
  >             if event == "linkrevfixup":
  >                 self.write("linkrevfixup: %s %s\n" % (opts.get("filepath"), opts.get("fnode")))
  >             return super(loglinkrevfixup, self).log(event, *msg, **opts)
  >     ui.__class__ = loglinkrevfixup
  > EOF

setup configuration
  $ INFINITEPUSH_ALLOW_WRITES=true setup_common_config
  $ cd $TESTTMP

setup repo
  $ testtool_drawdag -R repo --no-default-files --print-hg-hashes --derive-all <<EOF
  > A
  > # modify: A "file" "content0\n"
  > # bookmark: A master_bookmark
  > EOF
  A=4a0c0777ac93638e97b447f81d16f7de5afea095

start mononoke
  $ start_and_wait_for_mononoke_server

setup repo-push and repo-pull
  $ cd $TESTTMP
  $ for name in push pull1 pull2 pull3
  > do
  >   hg clone -q mono:repo repo-$name --noupdate
  >   cat >> repo-$name/.hg/hgrc <<EOF
  > [extensions]
  > loglinkrevfixup = $TESTTMP/loglinkrevfixup.py
  > commitcloud =
  > [infinitepush]
  > branchpattern = re:scratch/.*
  > EOF
  >   # Defeat shared cache between repos.
  >   cat >> repo-$name/.hg/hgrc <<EOF
  > [remotefilelog]
  > cachepath=$TESTTMP/cachepath/$name
  > EOF
  > done
push an infinitepush commit with new content
  $ cd $TESTTMP/repo-push
  $ hg up master_bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo "content1" > file
  $ hg commit -q -m branch
  $ BRANCH_HASH=$(hg log -r . -T '{node}')
  $ hg cloud backup
  commitcloud: head 'e7bc2b151947' hasn't been uploaded yet
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  $ hg log -G -T '{node} {desc} ({remotenames})\n' -r "all()"
  @  e7bc2b151947e75e509e9a4945158e6d3b408198 branch ()
  │
  o  4a0c0777ac93638e97b447f81d16f7de5afea095 A (remote/master_bookmark)
  


pull the infinitepush commit
  $ cd $TESTTMP/repo-pull1
  $ hg pull -r $BRANCH_HASH
  pulling from mono:repo
  searching for changes
  $ hg up $BRANCH_HASH
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg debugapi -e history -i '[("file", "b4aa7b980f00bcd3ea58510798c1425dcdc511f3")]'
  [{"key": {"node": bin("b4aa7b980f00bcd3ea58510798c1425dcdc511f3"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
                              "path": "file"},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("0000000000000000000000000000000000000000")}},
   {"key": {"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("4a0c0777ac93638e97b447f81d16f7de5afea095")}}]

NOTE: Mononoke gave us a NULL linknode

  $ echo othercontent > file2
  $ hg commit -Aqm other
  $ hg log -T '{node} {desc} ({remotenames})\n' -f file
  linkrevfixup: file b4aa7b980f00bcd3ea58510798c1425dcdc511f3
  e7bc2b151947e75e509e9a4945158e6d3b408198 branch ()
  4a0c0777ac93638e97b447f81d16f7de5afea095 A (remote/master_bookmark)

NOTE: linkrevfixup was called to fix up the null linkrev

push a master commit with the same content
  $ cd $TESTTMP/repo-push
  $ hg up master_bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo "content1" > file
  $ hg commit -q -m master
  $ MASTER_HASH=$(hg log -r . -T '{node}')
  $ hg push --to master_bookmark
  pushing rev 4a027d81b6ff to destination mono:repo bookmark master_bookmark
  searching for changes
  updating bookmark master_bookmark

Make sure the server derives the linknode info for public commit.
  $ mononoke_admin derived-data -R repo derive -T hgchangesets -T filenodes -B master_bookmark

pull only the master branch into another repo
  $ cd $TESTTMP/repo-pull2
  $ hg up master_bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg pull -B master_bookmark
  pulling from mono:repo
  imported commit graph for 1 commit (1 segment)
  $ hg up master_bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg log -G -T '{node} {desc} ({remotenames})\n' -r "all()"
  @  4a027d81b6ffa3fff7a686acf8e49a65dc84f8b9 master (remote/master_bookmark)
  │
  o  4a0c0777ac93638e97b447f81d16f7de5afea095 A ()
  


  $ hg debugapi -e history -i '[("file", "b4aa7b980f00bcd3ea58510798c1425dcdc511f3")]'
  [{"key": {"node": bin("b4aa7b980f00bcd3ea58510798c1425dcdc511f3"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
                              "path": "file"},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("4a027d81b6ffa3fff7a686acf8e49a65dc84f8b9")}},
   {"key": {"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("4a0c0777ac93638e97b447f81d16f7de5afea095")}}]

NOTE: the linknode is the public commit

  $ echo othercontent > file2
  $ hg commit -Aqm other
  $ hg log -T '{node} {desc} ({remotenames})\n' -f file
  4a027d81b6ffa3fff7a686acf8e49a65dc84f8b9 master (remote/master_bookmark)
  4a0c0777ac93638e97b447f81d16f7de5afea095 A ()

NOTE: linkrevfixup was not called

pull the infinitepush commit again in a new repo
  $ cd $TESTTMP/repo-pull3
  $ hg pull -qr $BRANCH_HASH
  $ hg up $BRANCH_HASH
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ hg debugapi -e history -i '[("file", "b4aa7b980f00bcd3ea58510798c1425dcdc511f3")]'
  [{"key": {"node": bin("b4aa7b980f00bcd3ea58510798c1425dcdc511f3"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
                              "path": "file"},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("4a027d81b6ffa3fff7a686acf8e49a65dc84f8b9")}},
   {"key": {"node": bin("599997c6080f1c12417bbc03894af754eea8dc72"),
            "path": "file"},
    "nodeinfo": {"parents": [{"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""},
                             {"node": bin("0000000000000000000000000000000000000000"),
                              "path": ""}],
                 "linknode": bin("4a0c0777ac93638e97b447f81d16f7de5afea095")}}]

NOTE: Mononoke gave us the public commit as the linknode

  $ echo othercontent > file2
  $ hg commit -Aqm other
  $ hg log -T '{node} {desc} ({remotenames})\n' -f file
  linkrevfixup: file b4aa7b980f00bcd3ea58510798c1425dcdc511f3
  e7bc2b151947e75e509e9a4945158e6d3b408198 branch ()
  4a0c0777ac93638e97b447f81d16f7de5afea095 A ()

NOTE: linkrevfixup was called to fix up the linkrev
