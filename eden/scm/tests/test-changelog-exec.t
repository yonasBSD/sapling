
#require execbit no-eden

b51a8138292a introduced a regression where we would mention in the
changelog executable files added by the second parent of a merge. Test
that that doesn't happen anymore


  $ sl init repo
  $ cd repo
  $ echo foo > foo
  $ sl ci -qAm 'add foo'

  $ echo bar > bar
  $ chmod +x bar
  $ sl ci -qAm 'add bar'

manifest of p2:

  $ sl manifest
  bar
  foo

  $ sl up -qC bbd179dfa0a71671c253b3ae0aa1513b60d199fa
  $ echo >> foo
  $ sl ci -m 'change foo'

manifest of p1:

  $ sl manifest
  foo

  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ chmod +x foo
  $ sl ci -m 'merge'

this should not mention bar but should mention foo:

  $ sl tip -v
  commit:      c53d17ff3380
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo
  description:
  merge
  
  

  $ sl debugindex bar
     rev linkrev nodeid       p1           p2
       0       1 b004912a8510 000000000000 000000000000

  $ cd ..
