
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo

  $ newclientrepo

  $ echo foo > foo
  $ echo bar > bar
  $ sl ci -qAm 'add foo bar'

  $ echo foo2 >> foo
  $ echo bleh > bar
  $ sl ci -m 'change foo bar'

  $ sl up -qC 'desc(add)'
  $ sl mv foo foo1
  $ echo foo1 > foo1
  $ sl cat foo >> foo1
  $ sl ci -m 'mv foo foo1'

  $ sl merge
  merging foo1 and foo to foo1
  1 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl debugstate --nodates
  m   0         -2 unset               bar
  m   0         -2 unset               foo1
  copy: foo -> foo1

  $ sl st -q
  M bar
  M foo1


Removing foo1 and bar:

  $ cp foo1 F
  $ cp bar B
  $ sl rm -f foo1 bar

  $ sl debugstate --nodates
  r   0         -2 unset               bar
  r   0         -2 unset               foo1
  copy: foo -> foo1

  $ sl st -qC
  R bar
  R foo1


Re-adding foo1 and bar:

  $ cp F foo1
  $ cp B bar
  $ sl add -v foo1 bar
  adding bar
  adding foo1

  $ sl debugstate --nodates
  n   0         -2 unset               bar
  n   0         -2 unset               foo1
  copy: foo -> foo1

  $ sl st -qC
  M bar
  M foo1
    foo


Reverting foo1 and bar:

  $ sl revert -vr . foo1 bar
  saving current version of bar as bar.orig
  reverting bar
  saving current version of foo1 as foo1.orig
  reverting foo1

  $ sl debugstate --nodates
  n   0         -2 unset               bar
  n   0         -2 unset               foo1
  copy: foo -> foo1

  $ sl st -qC
  M bar
  M foo1
    foo

  $ sl diff

Merge should not overwrite local file that is untracked after remove

  $ rm *
  $ sl up -qC .
  $ sl rm bar
  $ sl ci -m 'remove bar'
  $ echo 'memories of buried pirate treasure' > bar
  $ sl merge
  bar: untracked file differs
  abort: untracked files in working directory differ from files in requested revision
  [255]
  $ cat bar
  memories of buried pirate treasure

Those who use force will lose

  $ sl merge -f
  other [merge rev] changed bar which local [working copy] is missing
  hint: the missing file was probably deleted by commit d72d87f5f053 in the branch rebasing onto
  use (c)hanged version, leave (d)eleted, or leave (u)nresolved, or input (r)enamed path? u
  merging foo1 and foo to foo1
  0 files updated, 1 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ cat bar
  bleh
  $ sl st
  M bar
  M foo1
