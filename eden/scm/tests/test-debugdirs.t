#debugruntest-compatibile

#require no-eden


# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ newrepo

  $ for d in a a/b a/b/c a/b/d b/c/ b/d; do
  >   mkdir -p $d
  >   touch $d/x
  > done

  $ sl commit -Aqm init

  $ sl debugdirs a a/b a/b/c a/b/d b/c/ b/d m m/n a/b/m b/m/ b/m/n
  a
  a/b
  a/b/c
  a/b/d
  b/c/
  b/d
