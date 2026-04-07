
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ newrepo
  $ sl d

  $ sl di --config alias.did=root

  $ sl debugf
  unknown command 'debugf'
  (use 'sl help' to get help)
  [255]
