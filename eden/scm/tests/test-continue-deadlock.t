
#require no-eden


  $ export HGIDENTITY=sl
  $ enable rebase smartlog

Prepare repo

  $ newclientrepo
  $ echo 1 >> x
  $ sl ci -Am 'add x'
  adding x
  $ sl mv x y
  $ sl ci -m 'mv x -> y'
  $ cat y
  1
  $ sl prev
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  [8cdbe9] add x
  $ echo 2 >> x
  $ sl ci -m 'update x'

  $ sl rebase -s . -d 'desc("mv x -> y")' --config copytrace.dagcopytrace=False
  rebasing d6e243dd00b2 "update x"
  other [source] changed x which local [dest] is missing
  hint: if this is due to a renamed file, you can manually input the renamed path
  use (c)hanged version, leave (d)eleted, or leave (u)nresolved, or input (r)enamed path? u
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl st
  M x
  $ sl resolve --mark x
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl cont
  rebasing d6e243dd00b2 "update x"
