
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# TODO: Make this test compatible with obsstore enabled.

  $ eagerepo
  $ setconfig 'experimental.evolution='

# Set up extensions (order is important here, we must test tweakdefaults loading last)

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > rebase=
  > tweakdefaults=
  > EOF

# Run test

  $ sl init repo
  $ cd repo
  $ touch a
  $ sl commit -Aqm a
  $ touch b
  $ sl commit -Aqm b
  $ sl bookmark AB
  $ sl up '.^'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark AB)
  $ touch c
  $ sl commit -Aqm c
  $ sl bookmark C -t AB
  $ sl rebase
  rebasing d5e255ef74f8 "c" (C)
