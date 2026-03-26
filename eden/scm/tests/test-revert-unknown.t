
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
  $ touch unknown

  $ touch a
  $ sl add a
  $ sl ci -m initial

  $ touch b
  $ sl add b
  $ sl ci -m second

# Should show unknown

  $ sl status
  ? unknown
  $ sl revert -r 'desc(initial)' --all
  removing b

# Should show unknown and b removed

  $ sl status
  R b
  ? unknown

# Should show a and unknown

  $ ls
  a
  unknown
