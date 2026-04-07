
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# sl goto --inactive should behave like update except that
# it should not activate deactivated bookmarks and
# should not print the related ui.status outputs
# (eg: "activating bookmarks")
# Set up the repository.

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ sl debugbuilddag -m '+4 *3 +1'
  $ sl bookmark -r 7db39547e641 test
  $ sl goto test
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark test)
  $ sl bookmarks
   * test                      7db39547e641
  $ sl bookmark -i test
  $ sl goto --inactive test
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bookmarks
     test                      7db39547e641
  $ sl bookmark -r 09bb8c08de89 test2
  $ sl goto test
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark test)
  $ sl goto --inactive test2
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark test)
  $ sl bookmarks
     test                      7db39547e641
     test2                     09bb8c08de89
  $ sl goto --inactive test
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bookmarks
     test                      7db39547e641
     test2                     09bb8c08de89
