
#require no-eden


  $ export HGIDENTITY=sl
  $ configure modern
  $ enable amend rebase

  $ setconfig amend.autorestack=no-conflict
  $ setconfig rebase.experimental.inmemory=True

Tests the --noconflict rebase flag

  $ newrepo
  $ sl debugdrawdag << 'EOS'
  > E
  > |
  > D
  > |
  > C
  > |
  > B   # B/E=BE
  > |
  > A
  > EOS

Amend. Auto-restack partially succeeded:

  $ sl up -q B
  $ echo 3 >> E
  $ sl amend
  restacking children automatically (unless they conflict)
  rebasing 0cd970638c1e "C" (C)
  rebasing 77a55c942fba "D" (D)
  rebasing a98af8665cf0 "E" (E)
  merging E
  restacking would create conflicts (hit merge conflicts in E), so you must run it manually
  (run `sl restack` manually to restack this commit's children)

Commit B, C, D are rebased. Bookmarks are moved.

  $ sl log -r 'all()' -G -T '{desc} {bookmarks}'
  o  D D
  │
  o  C C
  │
  @  B B
  │
  │ o  E E
  │ │
  │ x  D
  │ │
  │ x  C
  │ │
  │ x  B
  ├─╯
  o  A A
  
Start restacking the rest (E):

  $ sl rebase --restack
  rebasing a98af8665cf0 "E" (E)
  merging E
  hit merge conflicts (in E); switching to on-disk merge
  rebasing a98af8665cf0 "E" (E)
  merging E
  warning: 1 conflicts while merging E! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ echo Resolved > E
  $ sl resolve -m E
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl continue
  rebasing a98af8665cf0 "E" (E)

All rebased bookmarks are moved:

  $ sl log -r 'all()' -G -T '{desc} {bookmarks}'
  o  E E
  │
  o  D D
  │
  o  C C
  │
  @  B B
  │
  o  A A
  
