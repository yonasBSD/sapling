
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
  $ ls
  a
  $ echo This is file b1 > b
  $ sl add b
  $ sl commit -m 'commit #1'
  $ sl co 'desc("commit #0")'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

# B should disappear

  $ ls
  a
