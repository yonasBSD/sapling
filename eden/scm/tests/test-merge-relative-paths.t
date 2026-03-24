
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Test that checks that relative paths are used in merge

  $ unset HGMERGE # make sure HGMERGE doesn't interfere with the test
  $ sl init repo
  $ cd repo

  $ mkdir dir && echo a > dir/file
  $ sl ci -Aqm first

  $ sl up -q null
  $ mkdir dir && echo b > dir/file
  $ sl ci -Aqm second

  $ sl up -q 'desc(first)'

  $ sl merge 'desc(second)'
  merging dir/file
  warning: 1 conflicts while merging dir/file! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

  $ sl up -q -C .
  $ cd dir
  $ sl merge 'desc(second)'
  merging file
  warning: 1 conflicts while merging file! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

Merging with different paths
  $ cd ..
  $ rm -rf repo
  $ sl init repo
  $ cd repo
  $ mkdir dir && echo a > dir/file
  $ sl ci -Aqm common
  $ echo b > dir/file
  $ sl commit -Am modify

  $ sl up -q 'desc(common)'
  $ mkdir dir2
  $ sl mv dir/file dir2/file
  $ sl ci -Aqm move
  $ sl merge 'desc(modify)'
  merging dir2/file and dir/file to dir2/file
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl up -q -C .
  $ cd dir2
  $ sl merge 'desc(modify)'
  merging file and ../dir/file to file
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

