
#require execbit no-eden

  $ eagerepo

  $ sl init repo
  $ cd repo
  $ echo a > a
  $ sl ci -Am'not executable'
  adding a

  $ chmod +x a
  $ sl ci -m'executable'
  $ sl id
  79abf14474dc

Make sure we notice the change of mode if the cached size == -1:

  $ sl rm a
  $ sl revert -r d69afc33ff8a77eda0ccb79374772831912446c3 a
  $ sl debugstate
  n   0         -1 unset               a
  $ sl status
  M a

  $ sl up -C d69afc33ff8a77eda0ccb79374772831912446c3
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl id
  d69afc33ff8a
  $ test -x a && echo executable -- bad || echo not executable -- good
  not executable -- good

