# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

#require symlink no-eden

# https://bz.mercurial-scm.org/1438

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo

  $ ln -s foo link
  $ sl add link
  $ sl ci -mbad link
  $ sl rm link
  $ sl ci -mok
  $ sl diff -g -r 'desc(bad)' -r 'desc(ok)' > bad.patch

  $ sl up 'desc(bad)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl import --no-commit bad.patch
  applying bad.patch

  $ sl status
  R link
  ? bad.patch
