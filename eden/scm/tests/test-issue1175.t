
#require no-eden


https://bz.mercurial-scm.org/1175

  $ setconfig commands.update.check=none

  $ newrepo repo
  $ touch a
  $ sl ci -Am0
  adding a

  $ sl mv a a1
  $ sl ci -m1

  $ sl co 'desc(0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ sl mv a a2
  $ sl up 'desc(1)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl ci -m2

  $ touch a
  $ sl ci -Am3
  adding a

  $ sl mv a b
  $ sl ci -Am4 a

  $ sl ci --debug --traceback -Am5 b
  committing files:
  b
  warning: can't find ancestor for 'b' copied from 'a'!
  committing manifest
  committing changelog
  committed 83a687e8a97c80992ba385bbfd766be181bfb1d1

  $ sl verify
  warning: verify does not actually check anything in this repo

  $ sl export --git tip
  # SL changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 83a687e8a97c80992ba385bbfd766be181bfb1d1
  # Parent  1d1625283f71954f21d14c3d44d0ad3c019c597f
  5
  
  diff --git a/b b/b
  new file mode 100644

https://bz.mercurial-scm.org/show_bug.cgi?id=4476

  $ sl init foo
  $ cd foo
  $ touch a && sl ci -Aqm a
  $ sl mv a b
  $ echo b1 >> b
  $ sl ci -Aqm b1
  $ sl up 'desc(a)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl mv a b
  $ echo b2 >> b
  $ sl ci -Aqm b2
  $ sl graft 'desc(b1)'
  grafting 5974126fad84 "b1"
  merging b
  warning: 1 conflicts while merging b! (edit, then use 'sl resolve --mark')
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]
  $ echo a > b
  $ echo b3 >> b
  $ sl resolve --mark b
  (no more unresolved files)
  continue: sl graft --continue
  $ sl graft --continue
  grafting 5974126fad84 "b1"
  warning: can't find ancestor for 'b' copied from 'a'!
  $ sl log -f b -T 'changeset:   {node|short}\nsummary:     {desc}\n\n'
  changeset:   376d30ccffc0
  summary:     b1
  
  changeset:   416baaa2e5e4
  summary:     b2
  
  changeset:   3903775176ed
  summary:     a
  
