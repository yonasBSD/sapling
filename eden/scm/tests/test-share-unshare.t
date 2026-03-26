
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Share works with blackbox enabled:

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > blackbox =
  > share =
  > EOF

  $ sl init a
  $ sl share a b
  updating working directory
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd b
  $ sl unshare
