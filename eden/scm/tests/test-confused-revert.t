
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo foo > a
  $ sl add a
  $ sl commit -m 1

  $ echo bar > b
  $ sl add b
  $ sl remove a

# Should show a removed and b added:

  $ sl status
  A b
  R a

  $ sl revert --all
  undeleting a
  forgetting b

# Should show b unknown and a back to normal:

  $ sl status
  ? b

  $ rm b

  $ sl co -C 'desc(1)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo foo-a > a
  $ sl commit -m 2a

  $ sl co -C 'desc(1)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo foo-b > a
  $ sl commit -m 2b

  $ HGMERGE=true sl merge 'desc(2a)'
  merging a
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

# Should show foo-b:

  $ cat a
  foo-b

  $ echo bar > b
  $ sl add b
  $ rm a
  $ sl remove a

# Should show a removed and b added:

  $ sl status
  A b
  R a

# Revert should fail:

  $ sl revert
  abort: uncommitted merge with no revision specified
  (use 'sl goto' or see 'sl help revert')
  [255]

# Revert should be ok now:

  $ sl revert -r 'desc(2b)' --all
  undeleting a
  forgetting b

# Should show b unknown and a marked modified (merged):

  $ sl status
  M a
  ? b

# Should show foo-b:

  $ cat a
  foo-b
