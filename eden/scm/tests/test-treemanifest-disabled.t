
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ CACHEDIR=`pwd`/hgcache

  $ . "$TESTDIR/library.sh"

  $ sl init client1
  $ cd client1
  $ cat >> .sl/config << 'EOF'
  > [remotefilelog]
  > reponame=master
  > cachepath=$CACHEDIR
  > EOF

  $ echo a > a
  $ mkdir dir
  $ echo b > dir/b
  $ sl commit -Aqm 'initial commit'

  $ sl init ../client2
  $ cd ../client2
  $ sl pull -q ../client1
