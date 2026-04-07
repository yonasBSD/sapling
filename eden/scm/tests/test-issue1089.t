
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# https://bz.mercurial-scm.org/1089

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ mkdir a
  $ echo a > a/b
  $ sl ci -Am m
  adding a/b

  $ sl rm a
  removing a/b
  $ sl ci -m m a

  $ mkdir a b
  $ echo a > a/b
  $ sl ci -Am m
  adding a/b

  $ sl rm a
  removing a/b
  $ cd b

# Relative delete:

  $ sl ci -m m ../a

  $ cd ..
