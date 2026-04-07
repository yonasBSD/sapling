#require no-windows no-eden

  $ eagerepo

test merging things outside of the sparse checkout

  $ newclientrepo
  $ enable sparse

  $ echo foo > foo
  $ sl commit -m initial -A foo
  $ sl bookmark -ir. initial

  $ echo bar > bar
  $ sl commit -m 'feature - bar1' -A bar
  $ sl bookmark -ir. feature1

  $ sl goto --inactive -q initial
  $ echo bar2 > bar
  $ sl commit -m 'feature - bar2' -A bar
  $ sl bookmark -ir. feature2

  $ sl goto --inactive -q feature1
  $ sl sparse --exclude 'bar*'

  $ sl merge feature2 --tool :merge-other
  temporarily included 1 file(s) in the sparse checkout for merging
  merging bar
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

Verify bar was merged temporarily

  $ ls
  bar
  foo
  $ sl status
  M bar

Verify bar disappears automatically when the working copy becomes clean

  $ sl commit -m "merged"
  cleaned up 1 temporarily added file(s) from the sparse checkout
  $ sl bookmark -ir. merged
  $ sl status
  $ ls
  foo

  $ sl cat -r . bar
  bar2

Test merging things outside of the sparse checkout that are not in the working
copy

  $ sl debugstrip -q -r .
  $ sl up --inactive -q feature2
  $ touch branchonly
  $ sl ci -Aqm 'add branchonly'

  $ sl up --inactive -q feature1
  $ sl sparse -X branchonly
  $ sl merge feature2 --tool :merge-other
  temporarily included 1 file(s) in the sparse checkout for merging
  merging bar
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
