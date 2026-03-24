
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.


# Create an empty repo:

  $ export HGIDENTITY=sl
  $ newclientrepo a

# Try some commands:

  $ sl log
  $ sl histgrep wah
  [1]
  $ sl manifest

# Poke at a clone:

  $ sl push -r . -q --to book --create

  $ cd ..
  $ newclientrepo b a_server
  $ sl log
