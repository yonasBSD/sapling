
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# test that we don't interrupt the merge session if
# a file-level merge failed

  $ export HGIDENTITY=sl
  $ setconfig commands.update.check=none

  $ eagerepo
  $ sl init repo
  $ cd repo

  $ echo foo > foo
  $ echo a > bar
  $ sl ci -Am 'add foo'
  adding bar
  adding foo

  $ sl mv foo baz
  $ echo b >> bar
  $ echo quux > quux1
  $ sl ci -Am 'mv foo baz'
  adding quux1

  $ sl up -qC 'desc("add foo")'
  $ echo >> foo
  $ echo c >> bar
  $ echo quux > quux2
  $ sl ci -Am 'change foo'
  adding quux2

# test with the rename on the remote side

  $ HGMERGE=false sl merge
  merging bar
  merging foo and baz to baz
  merging bar failed!
  1 files updated, 1 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ sl resolve -l
  U bar
  R baz

# test with the rename on the local side

  $ sl up -C 'desc("mv foo")'
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ HGMERGE=false sl merge
  merging bar
  merging baz and foo to baz
  merging bar failed!
  1 files updated, 1 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

# show unresolved

  $ sl resolve -l
  U bar
  R baz

# unmark baz

  $ sl resolve -u baz

# show

  $ sl resolve -l
  U bar
  U baz
  $ sl st
  M bar
  M baz
  M quux2
  ? bar.orig

# re-resolve baz

  $ sl resolve baz
  merging baz and foo to baz

# after resolve

  $ sl resolve -l
  U bar
  R baz

# resolve all warning

  $ sl resolve
  abort: no files or directories specified
  (use --all to re-merge all unresolved files)
  [255]

# resolve all

  $ sl resolve -a
  merging bar
  warning: 1 conflicts while merging bar! (edit, then use 'sl resolve --mark')
  [1]

# after

  $ sl resolve -l
  U bar
  R baz

  $ cd ..
