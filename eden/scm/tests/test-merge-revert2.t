
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig commands.update.check=none
  $ sl init repo
  $ cd repo

  $ echo 'added file1' > file1
  $ echo 'another line of text' >> file1
  $ echo 'added file2' > file2
  $ sl add file1 file2
  $ sl commit -m 'added file1 and file2'

  $ echo 'changed file1' >> file1
  $ sl commit -m 'changed file1'

  $ sl -q log
  dfab7f3c2efb
  c3fa057dd86f
  $ sl id
  dfab7f3c2efb

  $ sl goto -C c3fa057dd86f
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl id
  c3fa057dd86f

  $ echo 'changed file1' >> file1
  $ sl id
  c3fa057dd86f+

  $ sl revert --no-backup --all
  reverting file1
  $ sl diff
  $ sl status
  $ sl id
  c3fa057dd86f

  $ sl goto tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl diff
  $ sl status
  $ sl id
  dfab7f3c2efb

  $ sl goto -C c3fa057dd86f
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 'changed file1 different' >> file1

  $ sl goto tip
  merging file1
  warning: 1 conflicts while merging file1! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]

  $ sl diff --nodates
  diff -r dfab7f3c2efb file1
  --- a/file1
  +++ b/file1
  @@ -1,3 +1,7 @@
   added file1
   another line of text
  +<<<<<<< working copy: c3fa057dd86f - test: added file1 and file2
  +changed file1 different
  +=======
   changed file1
  +>>>>>>> destination:  dfab7f3c2efb - test: changed file1

  $ sl status
  M file1
  ? file1.orig
  $ sl id
  dfab7f3c2efb+

  $ sl revert --no-backup --all
  reverting file1
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  dfab7f3c2efb

  $ sl revert -r tip --no-backup --all
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  dfab7f3c2efb

  $ sl goto -C .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl diff
  $ sl status
  ? file1.orig
  $ sl id
  dfab7f3c2efb
