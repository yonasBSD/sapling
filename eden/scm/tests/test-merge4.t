
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo This is file a1 > a
  $ sl add a
  $ sl commit -m 'commit #0'
  $ echo This is file b1 > b
  $ sl add b
  $ sl commit -m 'commit #1'
  $ sl goto 'desc("commit #0")'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo This is file c1 > c
  $ sl add c
  $ sl commit -m 'commit #2'
  $ sl merge 'desc("commit #1")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ rm b
  $ echo This is file c22 > c

# Test sl behaves when committing with a missing file added by a merge

  $ sl commit -m 'commit #3'
  abort: cannot commit merge with missing files
  [255]
