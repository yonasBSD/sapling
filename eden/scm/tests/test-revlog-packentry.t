
#require no-eden



  $ sl init repo
  $ cd repo

  $ touch foo
  $ sl ci -Am 'add foo'
  adding foo

  $ sl up -C null
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

this should be stored as a delta against rev 0

  $ echo foo bar baz > foo
  $ sl ci -Am 'add foo again'
  adding foo

  $ sl debugindex foo
     rev linkrev nodeid       p1           p2
       0       0 b80de5d13875 000000000000 000000000000
       1       1 0376abec49b8 000000000000 000000000000

  $ cd ..
