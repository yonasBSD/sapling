
#require no-eden



  $ eagerepo
Make sure that the internal merge tools (internal:fail, internal:local,
internal:union and internal:other) are used when matched by a
merge-pattern in hgrc

Make sure HGMERGE doesn't interfere with the test:

  $ unset HGMERGE

  $ sl init repo
  $ cd repo

Initial file contents:

  $ echo "line 1" > f
  $ echo "line 2" >> f
  $ echo "line 3" >> f
  $ sl ci -Am "revision 0"
  adding f

  $ cat f
  line 1
  line 2
  line 3

Branch 1: editing line 1:

  $ sed 's/line 1/first line/' f > f.new
  $ mv f.new f
  $ sl ci -Am "edited first line"

Branch 2: editing line 3:

  $ sl goto 'desc(revision)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sed 's/line 3/third line/' f > f.new
  $ mv f.new f
  $ sl ci -Am "edited third line"

Merge using internal:fail tool:

  $ echo "[merge-patterns]" > .sl/config
  $ echo "* = internal:fail" >> .sl/config

  $ sl merge
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

  $ cat f
  line 1
  line 2
  third line

  $ sl stat
  M f

Merge using internal:local tool:

  $ sl goto -C 'max(desc(edited))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sed 's/internal:fail/internal:local/' .sl/config > .sl/config.new
  $ mv .sl/config.new .sl/config

  $ sl merge
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f
  line 1
  line 2
  third line

  $ sl stat
  M f

Merge using internal:other tool:

  $ sl goto -C 'max(desc(edited))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sed 's/internal:local/internal:other/' .sl/config > .sl/config.new
  $ mv .sl/config.new .sl/config

  $ sl merge
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f
  first line
  line 2
  line 3

  $ sl stat
  M f

Merge using default tool:

  $ sl goto -C 'max(desc(edited))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm .sl/config

  $ sl merge
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f
  first line
  line 2
  third line

  $ sl stat
  M f

Merge using internal:union tool:

  $ sl goto -C 'max(desc(edited))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo "line 4a" >>f
  $ sl ci -Am "Adding fourth line (commit 4)"
  $ sl goto 'max(desc(edited))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo "line 4b" >>f
  $ sl ci -Am "Adding fourth line v2 (commit 5)"

  $ echo "[merge-patterns]" > .sl/config
  $ echo "* = internal:union" >> .sl/config

  $ sl merge 2e6ee5e3ca9741adb8dea438cf4481288efd73c3
  merging f
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f
  line 1
  line 2
  third line
  line 4b
  line 4a
