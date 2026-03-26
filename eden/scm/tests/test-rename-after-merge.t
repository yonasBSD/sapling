
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ enable amend

Issue746: renaming files brought by the second parent of a merge was
broken.

  $ newclientrepo

  $ echo a > a
  $ sl ci -Am a
  adding a

  $ echo b > b
  $ sl ci -Am b
  adding b

  $ sl goto -q 'desc(a)'
  $ echo a >> a
  $ sl ci -m a2

Merge branches:

  $ sl merge 'desc(b)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl st
  M b

Rename b as c:

  $ sl mv b c
  $ sl st
  A c
  R b

Rename back c as b:

  $ sl mv c b
  $ sl st
  M b

  $ cd ..

Issue 1476: renaming a first parent file into another first parent
file while none of them belong to the second parent was broken

  $ newclientrepo
  $ echo a > a
  $ sl ci -Am adda
  adding a
  $ echo b1 > b1
  $ echo b2 > b2
  $ sl ci -Am changea
  adding b1
  adding b2
  $ sl up -C 'desc(adda)'
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo c1 > c1
  $ echo c2 > c2
  $ sl ci -Am addcandd
  adding c1
  adding c2

Merge heads:

  $ sl merge
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl mv -Af c1 c2

Commit issue 1476:

  $ sl ci -m merge
  $ sl log -r tip -C -v | grep copies
  copies:      c2 (c1)

  $ sl hide . -q

  $ sl up -C 'desc(addcandd)' -q

Merge heads again:

  $ sl merge
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl mv -Af b1 b2

Commit issue 1476 with a rename on the other side:

  $ sl ci -m merge

  $ sl log -r tip -C -v | grep copies
  copies:      b2 (b1)

  $ cd ..
