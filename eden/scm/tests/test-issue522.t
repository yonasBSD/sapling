
#require no-eden


https://bz.mercurial-scm.org/522

In the merge below, the file "foo" has the same contents in both
parents, but if we look at the file-level history, we'll notice that
the version in p1 is an ancestor of the version in p2. This test makes
sure that we'll use the version from p2 in the manifest of the merge
revision.

  $ export HGIDENTITY=sl
  $ sl init repo
  $ cd repo

  $ echo foo > foo
  $ sl ci -qAm 'add foo'

  $ echo bar >> foo
  $ sl ci -m 'change foo'

  $ sl backout -r tip -m 'backout changed foo'
  reverting foo
  changeset 9eaf049ccce4 backs out changeset b515023e500e

  $ sl up -C 'desc(add)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ touch bar
  $ sl ci -qAm 'add bar'

  $ sl merge --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: bbd179dfa0a7, local: 71766447bdbb+, remote: 9eaf049ccce4
   foo: remote is newer -> g
  getting foo
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl debugstate | grep foo
  m   0         -2 unset               foo

  $ sl st -A foo
  M foo

  $ sl ci -m 'merge'

  $ sl manifest --debug | grep foo
  c6fc755d7e68f49f880599da29f15add41f42f5a 644   foo

  $ sl debugindex foo
     rev linkrev nodeid       p1           p2
       0       0 2ed2a3912a0b 000000000000 000000000000
       1       1 6f4310b00b9a 2ed2a3912a0b 000000000000
       2       2 c6fc755d7e68 6f4310b00b9a 000000000000

