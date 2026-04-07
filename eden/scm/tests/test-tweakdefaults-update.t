
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > tweakdefaults=
  > rebase=
  > [commands]
  > update.check=noconflict
  > EOF
  $ setconfig 'ui.suggesthgprev=True'

# Set up the repository.

  $ sl init repo
  $ cd repo
  $ sl debugbuilddag -m '+4 *3 +1'
  $ sl log --graph -r 'all()' -T '{desc}'
  o  r5
  │
  o  r4
  │
  │ o  r3
  │ │
  │ o  r2
  ├─╯
  o  r1
  │
  o  r0

  $ sl up 'desc(r3)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Make an uncommitted change.

  $ echo foo > foo
  $ sl add foo
  $ sl st
  A foo

# Can always update to current commit.

  $ sl up .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Abort with --check set, succeed with --merge

  $ sl up 'desc(r2)' --check
  abort: uncommitted changes
  [255]
  $ sl up --merge 'desc(r2)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Updates to other branches should fail without --merge.

  $ sl up 'desc(r4)' --check
  abort: uncommitted changes
  [255]
  $ sl up --merge 'desc(r4)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Certain flags shouldn't work together.

  $ sl up --check --merge 'desc(r3)'
  abort: can only specify one of -C/--clean, -c/--check, or -m/--merge
  [255]
  $ sl up --check --clean 'desc(r3)'
  abort: can only specify one of -C/--clean, -c/--check, or -m/--merge
  [255]
  $ sl up --clean --merge 'desc(r3)'
  abort: can only specify one of -C/--clean, -c/--check, or -m/--merge
  [255]

# --clean should work as expected.

  $ sl st
  A foo
  $ sl up --clean 'desc(r3)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl st
  ? foo
  $ enable amend
  $ sl goto '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  hint[update-prev]: use 'sl prev' to move to the parent changeset
  hint[hint-ack]: use 'sl hint --ack update-prev' to silence these hints
