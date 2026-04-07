
#require no-eden


  $ eagerepo
  $ configure mutation-norecord
  $ enable rebase

initialize repository

  $ sl init repo
  $ cd repo

  $ echo 'a' > a
  $ sl ci -A -m "0"
  adding a

  $ echo 'b' > b
  $ sl ci -A -m "1"
  adding b

  $ sl up 'desc(0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo 'c' > c
  $ sl ci -A -m "2"
  adding c

  $ echo 'd' > d
  $ sl ci -A -m "3"
  adding d

  $ sl bookmark -r 'desc(1)' one
  $ sl bookmark -r 'desc(3)' two
  $ sl up -q two

bookmark list

  $ sl bookmark
     one                       925d80f479bb
   * two                       2ae46b1d99a7

rebase

  $ sl rebase -s two -d one
  rebasing 2ae46b1d99a7 "3" (two)

  $ sl log
  commit:      42e5ed2cdcf4
  bookmark:    two
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     3
  
  commit:      db815d6d32e6
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     2
  
  commit:      925d80f479bb
  bookmark:    one
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     1
  
  commit:      f7b1eb17ad24
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  
aborted rebase should restore active bookmark.

  $ sl up 'desc(1)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark two)
  $ echo 'e' > d
  $ sl ci -A -m "4"
  adding d
  $ sl bookmark three
  $ sl rebase -s three -d two
  rebasing dd7c838e8362 "4" (three)
  merging d
  warning: 1 conflicts while merging d! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl rebase --abort
  rebase aborted
  $ sl bookmark
     one                       925d80f479bb
   * three                     dd7c838e8362
     two                       42e5ed2cdcf4

after aborted rebase, restoring a bookmark that has been removed should not fail

  $ sl rebase -s three -d two
  rebasing dd7c838e8362 "4" (three)
  merging d
  warning: 1 conflicts while merging d! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl bookmark -d three
  $ sl rebase --abort
  rebase aborted
  $ sl bookmark
     one                       925d80f479bb
     two                       42e5ed2cdcf4
