
#require no-eden


  $ eagerepo
  $ setconfig commands.update.check=none
  $ sl init repo
  $ cd repo

Revision 0:

  $ echo "unchanged" > unchanged
  $ echo "remove me" > remove
  $ echo "copy me" > copy
  $ echo "move me" > move
  $ for i in 1 2 3 4 5 6 7 8 9; do
  >     echo "merge ok $i" >> zzz1_merge_ok
  > done
  $ echo "merge bad" > zzz2_merge_bad
  $ sl ci -Am "revision 0"
  adding copy
  adding move
  adding remove
  adding unchanged
  adding zzz1_merge_ok
  adding zzz2_merge_bad

Revision 1:

  $ sl rm remove
  $ sl mv move moved
  $ sl cp copy copied
  $ echo "added" > added
  $ sl add added
  $ echo "new first line" > zzz1_merge_ok
  $ sl cat zzz1_merge_ok >> zzz1_merge_ok
  $ echo "new last line" >> zzz2_merge_bad
  $ sl ci -m "revision 1"

Local changes to revision 0:

  $ sl co c929647821fa73cdd20aa068da4153b2182c2731
  4 files updated, 0 files merged, 3 files removed, 0 files unresolved
  $ echo "new last line" >> zzz1_merge_ok
  $ echo "another last line" >> zzz2_merge_bad

  $ sl diff --nodates | grep "^[+-][^<>]"
  --- a/zzz1_merge_ok
  +++ b/zzz1_merge_ok
  +new last line
  --- a/zzz2_merge_bad
  +++ b/zzz2_merge_bad
  +another last line

  $ sl st
  M zzz1_merge_ok
  M zzz2_merge_bad

Local merge with bad merge tool:

  $ HGMERGE=false sl co tip
  merging zzz1_merge_ok
  merging zzz2_merge_bad
  merging zzz2_merge_bad failed!
  3 files updated, 1 files merged, 1 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]

  $ sl resolve -m
  (no more unresolved files)

  $ sl co c929647821fa73cdd20aa068da4153b2182c2731
  merging zzz1_merge_ok
  merging zzz2_merge_bad
  warning: 1 conflicts while merging zzz2_merge_bad! (edit, then use 'sl resolve --mark')
  2 files updated, 1 files merged, 3 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]

  $ sl diff --nodates | grep "^[+-][^<>]"
  --- a/zzz1_merge_ok
  +++ b/zzz1_merge_ok
  +new last line
  --- a/zzz2_merge_bad
  +++ b/zzz2_merge_bad
  +another last line
  +=======

  $ sl st
  M zzz1_merge_ok
  M zzz2_merge_bad
  ? zzz2_merge_bad.orig

Local merge with conflicts:

  $ sl resolve -m
  (no more unresolved files)

  $ sl co tip
  merging zzz1_merge_ok
  merging zzz2_merge_bad
  warning: 1 conflicts while merging zzz2_merge_bad! (edit, then use 'sl resolve --mark')
  3 files updated, 1 files merged, 1 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]

  $ sl resolve -m
  (no more unresolved files)

  $ sl co c929647821fa73cdd20aa068da4153b2182c2731 --config 'ui.origbackuppath=.hg/origbackups'
  merging zzz1_merge_ok
  merging zzz2_merge_bad
  warning: 1 conflicts while merging zzz2_merge_bad! (edit, then use 'sl resolve --mark')
  2 files updated, 1 files merged, 3 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]

Are orig files from the last commit where we want them?
  $ ls .sl/origbackups
  zzz2_merge_bad

  $ sl diff --nodates | grep "^[+-][^<>]"
  --- a/zzz1_merge_ok
  +++ b/zzz1_merge_ok
  +new last line
  --- a/zzz2_merge_bad
  +++ b/zzz2_merge_bad
  +another last line
  +=======
  +=======
  +new last line
  +=======

  $ sl st
  M zzz1_merge_ok
  M zzz2_merge_bad
  ? zzz2_merge_bad.orig

Local merge without conflicts:

  $ sl revert zzz2_merge_bad

  $ sl resolve -m
  (no more unresolved files)

  $ sl co tip
  merging zzz1_merge_ok
  4 files updated, 1 files merged, 1 files removed, 0 files unresolved

  $ sl diff --nodates | grep "^[+-][^<>]"
  --- a/zzz1_merge_ok
  +++ b/zzz1_merge_ok
  +new last line

  $ sl st
  M zzz1_merge_ok
  ? zzz2_merge_bad.orig

