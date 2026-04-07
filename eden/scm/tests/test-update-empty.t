# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.


#require no-eden


# Empty update fails with a helpful error:

  $ setconfig 'ui.disallowemptyupdate=True'
  $ newclientrepo
  $ sl debugdrawdag << 'EOS'
  > B
  > |
  > A
  > EOS
  $ sl up -q A
  $ sl up
  (If you're trying to move a bookmark forward, try "sl rebase -d <destination>".) (?)
  abort: you must specify a destination to update to, for example "sl goto main".
  [255]

# up -r works as intended:

  $ sl up -q -r B
  $ sl log -r . -T '{desc}\n'
  B
  $ sl up -q B
  $ sl log -r . -T '{desc}\n'
  B
