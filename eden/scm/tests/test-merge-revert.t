
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ setconfig commands.update.check=none

  $ sl init repo
  $ cd repo

  $ echo 'added file1' > file1
  $ echo 'added file2' > file2
  $ sl add file1 file2
  $ sl commit -m 'added file1 and file2'

  $ echo 'changed file1' >> file1
  $ sl commit -m 'changed file1'

  $ sl -q log
  08a16e8e4408
  d29c767a4b52
  $ sl id
  08a16e8e4408

  $ sl goto -C 'desc("added file1 and")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl id
  d29c767a4b52
  $ echo 'changed file1' >> file1
  $ sl id
  d29c767a4b52+

  $ sl revert --all
  reverting file1
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  d29c767a4b52

  $ sl goto tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  08a16e8e4408

  $ sl goto -C 'desc("added file1 and")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 'changed file1' >> file1

  $ sl goto tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  08a16e8e4408

  $ sl revert --all
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  08a16e8e4408

  $ sl revert -r tip --all
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  08a16e8e4408

  $ sl goto -C .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  08a16e8e4408
