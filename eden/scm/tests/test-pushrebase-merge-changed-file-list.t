#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ . $RUNTESTDIR/library.sh

Setup

  $ configure dummyssh
  $ setconfig ui.username="nobody <no.reply@fb.com>"

  $ log() {
  >   sl log -G -T "{desc} [{phase}:{node|short}] {remotenames}" "$@"
  > }

Set up server repository

  $ newserver server
  $ setconfig extensions.pushrebase=
  $ echo foo > a
  $ echo foo > b
  $ sl commit -Am 'initial'
  adding a
  adding b
  $ sl book -r . master

Clone client repository
  $ cd ..
  $ sl clone ssh://user@dummy/server client -q
  $ cd client
  $ setconfig extensions.pushrebase=

Add new commit
  $ cd ../server
  $ sl up -q master
  $ echo 'bar' > a
  $ sl commit -Am 'a => bar'

Create a merge commit that merges executable file in
  $ cd ../client
  $ sl up -q tip
  $ log -r .
  @  initial [public:2bb9d20e471c] remote/master
  
  $ sl up -q null
  $ echo ex > ex
  $ chmod +x ex
  $ sl ci -Aqm tomerge
  $ log -r .
  @  tomerge [draft:db9ca4f4d8f9]
  
  $ sl up -q 2bb9d20e471c
  $ sl merge -q db9ca4f4d8f9
  $ sl ci -m merge
  $ sl push -r . --to master -q

Check that file list contains no changed files, because a file were just merged in
  $ sl up -q tip
  $ sl log -r . -T '{files}'

Create a merge commit that merges a file and then makes it executable
  $ cd ../server
  $ sl up -q master
  $ mkcommit randomservercommit

  $ cd ../client
  $ sl up -q null
  $ echo no_exec > no_exec
  $ sl ci -Aqm tomerge_no_exec
  $ sl log -r . -T '{node}'
  38806fbf9b2d528b5e65b29edbb249ace57ca52e (no-eol)

  $ sl up -q 2bb9d20e471c
  $ sl merge -q 38806fbf9b2d
  $ chmod +x no_exec
  $ sl ci -m merge

  $ sl push -r . --to master -q
  $ sl up -q tip
  $ sl log -r . -T '{files}'
  no_exec (no-eol)

Create a merge commit that merges executable and non-executable files.
File list should be empty because we are keeping p1 flags
  $ cd ../server
  $ sl up -q master
  $ mkcommit randomservercommit2

  $ cd ../client
  $ sl up -q null
  $ echo no_exec_2 > no_exec_2
  $ sl ci -Aqm tomerge_no_exec

  $ sl log -r . -T '{node}'
  9c093b936a3cf120f340f16111bd80331029fd5c (no-eol)
  $ sl up -q master
  $ echo no_exec_2 > no_exec_2
  $ chmod +x no_exec_2
  $ sl commit -Aqm 'exec commit'
  $ sl merge -q 9c093b936a3cf120f340f16111bd80331029fd5c
  warning: cannot merge flags for no_exec_2 without common ancestor - keeping local flags

  $ sl ci -m merge
  $ sl push -q -r . --to master
  $ sl up -q tip
  $ sl log -r . -T '{files}'

Create a merge commit that merges executable and non-executable files.
File list should be non-empty because we are keeping p2 flags
  $ cd ../server
  $ sl up -q master
  $ mkcommit randomservercommit3

  $ cd ../client
  $ sl up -q null
  $ echo no_exec_3 > no_exec_3
  $ sl ci -Aqm tomerge_no_exec

  $ sl log -r . -T '{node}'
  84cb2313f1da1968f526b51ea263f81a6a9b9b1c (no-eol)
  $ sl up -q master
  $ echo no_exec_3 > no_exec_3
  $ chmod +x no_exec_3
  $ sl commit -Aqm 'exec commit'
  $ sl merge -q 84cb2313f1da1968f526b51ea263f81a6a9b9b1c
  warning: cannot merge flags for no_exec_3 without common ancestor - keeping local flags
  $ chmod -x no_exec_3

  $ sl ci -m merge
  $ sl push -q -r . --to master
  $ sl up -q tip
  $ sl log -r . -T '{files}'
  no_exec_3 (no-eol)
