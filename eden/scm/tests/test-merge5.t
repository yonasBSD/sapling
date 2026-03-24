
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo This is file a1 > a
  $ echo This is file b1 > b
  $ sl add a b
  $ sl commit -m 'commit #0'
  $ echo This is file b22 > b
  $ sl commit -m 'comment #1'
  $ sl goto 'desc("commit #0")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm b
  $ sl commit -A -m 'comment #2'
  removing b
  $ sl goto 'desc("comment #1")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm b
  $ sl goto -c 'desc("comment #2")'
  abort: uncommitted changes
  [255]
  $ sl revert b
  $ sl goto -c 'desc("comment #2")'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

# Should succeed:

  $ sl goto 'desc("comment #1")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
