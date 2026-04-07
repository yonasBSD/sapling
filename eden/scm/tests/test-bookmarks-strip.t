
#require no-eden


  $ configure modern
  $ sl init repo
  $ cd repo

  $ echo qqq>qqq.txt

add file

  $ sl add
  adding qqq.txt

commit first revision

  $ sl ci -m 1

set bookmark

  $ sl book test

  $ echo www>>qqq.txt

commit second revision

  $ sl ci -m 2

set bookmark

  $ sl book test2

update to -2 (deactivates the active bookmark)

  $ sl goto -r '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark test2)

  $ echo eee>>qqq.txt

commit new head

  $ sl ci -m 3

bookmarks updated?

  $ sl book
     test                      25e1ee7a0081
     test2                     25e1ee7a0081

strip to revision 1

  $ sl hide 'desc(2)'
  hiding commit 25e1ee7a0081 "2"
  1 changeset hidden
  removing bookmark 'test' (was at: 25e1ee7a0081)
  removing bookmark 'test2' (was at: 25e1ee7a0081)
  2 bookmarks removed

list bookmarks

  $ sl book
  no bookmarks set
