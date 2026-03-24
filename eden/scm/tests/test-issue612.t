
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# https://bz.mercurial-scm.org/612

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo
  $ mkdir src
  $ echo a > src/a.c
  $ sl ci -Am 'init'
  adding src/a.c

  $ sl mv src source
  moving src/a.c to source/a.c

  $ sl ci -Ammove

  $ sl co -C 'desc(init)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ echo new > src/a.c
  $ echo compiled > src/a.o
  $ sl ci -mupdate

  $ sl status
  ? src/a.o

  $ sl merge
  merging src/a.c and source/a.c to source/a.c
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl status
  M source/a.c
  R src/a.c
  ? src/a.o
