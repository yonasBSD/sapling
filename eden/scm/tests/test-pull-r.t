#modern-config-incompatible

#require no-eden


  $ configure dummyssh
  $ sl init repo
  $ cd repo
  $ echo foo > foo
  $ sl ci -qAm 'add foo'
  $ echo >> foo
  $ sl ci -m 'change foo'
  $ sl up -qC 'desc(add)'
  $ echo bar > bar
  $ sl ci -qAm 'add bar'

  $ sl log
  commit:      effea6de0384
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add bar
  
  commit:      ed1b79f46b9a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     change foo
  
  commit:      bbd179dfa0a7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add foo
  
  $ cd ..

don't show "(+1 heads)" message when pulling closed head

  $ sl clone -q repo repo2
  $ sl clone -q repo2 repo3
  $ cd repo2
  $ sl up -q bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  $ echo hello >> foo
  $ sl ci -mx1
  $ sl ci -mx2 --config ui.allowemptycommit=1
  $ sl book master
  $ cd ../repo3
  $ sl heads -q --closed
  effea6de0384
  $ sl pull
  pulling from $TESTTMP/repo2
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  $ sl heads -q --closed
  effea6de0384
  1a1aa123db21

  $ cd ..

  $ sl init copy
  $ cd copy

Pull a missing revision:

  $ sl pull -qr missing ../repo
  abort: unknown revision 'missing'!
  [255]

Pull multiple revisions with update:

  $ cp -R . $TESTTMP/copy1
  $ cd $TESTTMP/copy1
  $ sl pull -qu -r bbd179dfa0a7 -r ed1b79f46b9a ../repo
  $ sl -q parents
  bbd179dfa0a7

  $ cd $TESTTMP/copy
  $ sl pull -qr bbd179dfa0a7 ../repo
  $ sl log
  commit:      bbd179dfa0a7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add foo
  
  $ sl pull -qr ed1b79f46b9a ../repo
  $ sl log
  commit:      ed1b79f46b9a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     change foo
  
  commit:      bbd179dfa0a7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add foo
  

This used to abort: received changelog group is empty:

  $ sl pull -qr ed1b79f46b9a ../repo
