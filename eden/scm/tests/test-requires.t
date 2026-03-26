
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init t
  $ cd t
  $ echo a > a
  $ sl add a
  $ sl commit -m test
  $ rm .sl/requires
  $ sl tip
  abort: '$TESTTMP/t' is not inside a repository, but this command requires a repository!
  (use 'cd' to go to a directory inside a repository and try again)
  [255]
  $ echo indoor-pool > .sl/requires
  $ sl tip
  abort: repository requires unknown features: indoor-pool
  (consider upgrading Sapling)
  [255]
  $ echo outdoor-pool >> .sl/requires
  $ sl tip
  abort: repository requires unknown features: indoor-pool, outdoor-pool
  (consider upgrading Sapling)
  [255]
  $ cd ..
