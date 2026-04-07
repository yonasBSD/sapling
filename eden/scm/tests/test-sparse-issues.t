
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo

  $ enable sparse
  $ newrepo
  $ sl sparse include a/b
  $ cat .sl/sparse
  [include]
  a/b
  [exclude]
  $ mkdir -p a/b b/c
  $ touch a/b/c b/c/d

  $ sl status
  ? a/b/c

# More complex pattern

  $ sl sparse include 'a*/b*/c'
  $ mkdir -p a1/b1
  $ touch a1/b1/c

  $ sl status
  ? a/b/c
  ? a1/b1/c
