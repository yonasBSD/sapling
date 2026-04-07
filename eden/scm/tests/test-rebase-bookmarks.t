#modern-config-incompatible

#require no-eden


  $ enable rebase

Create a repo with several bookmarks
  $ sl init a
  $ cd a

  $ echo a > a
  $ sl ci -Am A
  adding a

  $ echo b > b
  $ sl ci -Am B
  adding b
  $ sl book 'X'
  $ sl book 'Y'

  $ echo c > c
  $ sl ci -Am C
  adding c
  $ sl book 'Z'

  $ sl up -q 'desc(A)'

  $ echo d > d
  $ sl ci -Am D
  adding d

  $ sl book W

  $ tglog
  @  41acb9dca9eb 'D' W
  │
  │ o  49cb3485fa0c 'C' Y Z
  │ │
  │ o  6c81ed0049f8 'B' X
  ├─╯
  o  1994f17a630e 'A'
  

Move only rebased bookmarks

  $ cd ..
  $ cp -r a a1

  $ cd a1
  $ sl up -q Z

Test deleting divergent bookmarks from dest (issue3685)

  $ sl book -r 'desc(D)' Z@diverge

... and also test that bookmarks not on dest or not being moved aren't deleted

  $ sl book -r 'desc(D)' X@diverge
  $ sl book -r 'desc(A)' Y@diverge

  $ tglog
  o  41acb9dca9eb 'D' W X@diverge Z@diverge
  │
  │ @  49cb3485fa0c 'C' Y Z
  │ │
  │ o  6c81ed0049f8 'B' X
  ├─╯
  o  1994f17a630e 'A' Y@diverge
  
  $ sl rebase -s Y -d 'desc(D)'
  rebasing 49cb3485fa0c "C" (Y Z)

  $ tglog
  @  17fb3faba63c 'C' Y Z
  │
  o  41acb9dca9eb 'D' W X@diverge
  │
  │ o  6c81ed0049f8 'B' X
  ├─╯
  o  1994f17a630e 'A' Y@diverge
  
Do not try to keep active but deleted divergent bookmark

  $ cd ..
  $ cp -r a a4

  $ cd a4
  $ sl up -q 'desc(C)'
  $ sl book W@diverge

  $ sl rebase -s W -d .
  rebasing 41acb9dca9eb "D" (W)

  $ sl bookmarks
     W                         0d3554f74897
     X                         6c81ed0049f8
     Y                         49cb3485fa0c
     Z                         49cb3485fa0c

Keep bookmarks to the correct rebased changeset

  $ cd ..
  $ cp -r a a2

  $ cd a2
  $ sl up -q Z

  $ sl rebase -s 'desc(B)' -d 'desc(D)'
  rebasing 6c81ed0049f8 "B" (X)
  rebasing 49cb3485fa0c "C" (Y Z)

  $ tglog
  @  3d5fa227f4b5 'C' Y Z
  │
  o  e926fccfa8ec 'B' X
  │
  o  41acb9dca9eb 'D' W
  │
  o  1994f17a630e 'A'
  

Keep active bookmark on the correct changeset

  $ cd ..
  $ cp -r a a3

  $ cd a3
  $ sl up -q X

  $ sl rebase -d W
  rebasing 6c81ed0049f8 "B" (X)
  rebasing 49cb3485fa0c "C" (Y Z)

  $ tglog
  o  3d5fa227f4b5 'C' Y Z
  │
  @  e926fccfa8ec 'B' X
  │
  o  41acb9dca9eb 'D' W
  │
  o  1994f17a630e 'A'
  
  $ sl bookmarks
     W                         41acb9dca9eb
   * X                         e926fccfa8ec
     Y                         3d5fa227f4b5
     Z                         3d5fa227f4b5

rebase --continue with bookmarks present (issue3802)

  $ sl up 'bookmark(X)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark X)
  $ echo 'C' > c
  $ sl add c
  $ sl ci -m 'other C'
  $ sl up 'bookmark(Y)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl rebase --dest 'desc(other)'
  rebasing 3d5fa227f4b5 "C" (Y Z)
  merging c
  warning: 1 conflicts while merging c! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ echo 'c' > c
  $ sl resolve --mark c
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  rebasing 3d5fa227f4b5 "C" (Y Z)
  $ tglog
  @  45c0f0ec1203 'C' Y Z
  │
  o  b0e10b7175fd 'other C'
  │
  o  e926fccfa8ec 'B' X
  │
  o  41acb9dca9eb 'D' W
  │
  o  1994f17a630e 'A'
  

ensure that bookmarks given the names of revset functions can be used
as --rev arguments (issue3950)

  $ sl goto -q 'desc(other)'
  $ echo bimble > bimble
  $ sl add bimble
  $ sl commit -q -m 'b1'
  $ echo e >> bimble
  $ sl ci -m b2
  $ echo e >> bimble
  $ sl ci -m b3
  $ sl book bisect
  $ sl goto -q Y
  $ sl rebase -r '"bisect"^^::"bisect"^' -r bisect -d Z
  rebasing 49529c8ce0a4 "b1"
  rebasing 2d12d2701d8f "b2"
  rebasing d19a263ead4a "b3" (bisect)

Bookmark and working parent get moved even if --keep is set (issue5682)

  $ sl init $TESTTMP/book-keep
  $ cd $TESTTMP/book-keep
  $ drawdag <<'EOS'
  > B C
  > |/
  > A
  > EOS
  $ sl up -q $B
  $ tglog
  o  dc0947a82db8 'C'
  │
  │ @  112478962961 'B'
  ├─╯
  o  426bada5c675 'A'
  
  $ sl rebase -r $B -d $C --keep
  rebasing 112478962961 "B"
  $ tglog
  @  9769fc65c4c5 'B'
  │
  o  dc0947a82db8 'C'
  │
  │ o  112478962961 'B'
  ├─╯
  o  426bada5c675 'A'
  

