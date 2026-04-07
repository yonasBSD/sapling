
#require no-eden


# enable bundle2 in advance
  $ setconfig format.usegeneraldelta=yes

  $ mkdir part1
  $ cd part1

  $ sl init
  $ echo a > a
  $ sl add a
  $ sl commit -m "1"
  $ sl status
  $ sl copy a b
  $ sl --config ui.portablefilenames=abort copy a con.xml
  abort: filename contains 'con', which is reserved on Windows: con.xml
  [255]
  $ sl status
  A b
  $ sl sum
  parent: c19d34741b0a 
   1
  commit: 1 copied
  phases: 1 draft
  $ sl --debug commit -m "2"
  committing files:
  b
   b: copy a:b789fdd96dc2f3bd229c1dd8eedf0fc60e2b68e3
  committing manifest
  committing changelog
  committed 93580a2c28a50a56f63526fb305067e6fbf739c4

we should see two history entries

  $ sl history -v
  commit:      93580a2c28a5
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       b
  description:
  2
  
  
  commit:      c19d34741b0a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       a
  description:
  1
  
  

we should see one log entry for a

  $ sl log a
  commit:      c19d34741b0a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     1
  

this should show a revision linked to changeset 0

  $ sl debugindex a
     rev linkrev nodeid       p1           p2
       0       0 b789fdd96dc2 000000000000 000000000000

we should see one log entry for b

  $ sl log b
  commit:      93580a2c28a5
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     2
  

this should show a revision linked to changeset 1

  $ sl debugindex b
     rev linkrev nodeid       p1           p2
       0       1 37d9b5d994ea 000000000000 000000000000

this should show the rename information in the metadata

  $ sl debugdata b 0 | head -3 | tail -2
  copy: a
  copyrev: b789fdd96dc2f3bd229c1dd8eedf0fc60e2b68e3

  $ sl cat b > bsum
  $ f --md5 bsum
  bsum: md5=60b725f10c9c85c70d97880dfe8191b3
  $ sl cat a > asum
  $ f --md5 asum
  asum: md5=60b725f10c9c85c70d97880dfe8191b3
  $ sl verify
  warning: verify does not actually check anything in this repo

  $ cd ..


  $ mkdir part2
  $ cd part2

  $ sl init
  $ echo foo > foo
should fail - foo is not managed
  $ sl mv foo bar
  foo: not copying - file is not managed
  abort: no files to copy
  (use '--amend --mark' if you want to amend the current commit)
  [255]
  $ sl st -A
  ? foo
  $ sl add foo
dry-run; print a warning that this is not a real copy; foo is added
  $ sl mv --dry-run foo bar
  foo has not been committed yet, so no copy data will be stored for bar.
  $ sl st -A
  A foo
should print a warning that this is not a real copy; bar is added
  $ sl mv foo bar
  foo has not been committed yet, so no copy data will be stored for bar.
  $ sl st -A
  A bar
should print a warning that this is not a real copy; foo is added
  $ sl cp bar foo
  bar has not been committed yet, so no copy data will be stored for foo.
  $ sl rm -f bar
  $ rm bar
  $ sl st -A
  A foo
  $ sl commit -m1

moving a missing file
  $ rm foo
  $ sl mv foo foo3
  foo: deleted in working directory
  foo3 does not exist!
  $ sl up -qC .

copy --mark to a nonexistent target filename
  $ sl cp --mark foo dummy
  foo: not recording copy - dummy does not exist

dry-run; should show that foo is clean
  $ sl copy --dry-run foo bar
  $ sl st -A
  C foo
should show copy
  $ sl copy foo bar
  $ sl st -C
  A bar
    foo

shouldn't show copy
  $ sl commit -m2
  $ sl st -C

should match
  $ sl debugindex foo
     rev linkrev nodeid       p1           p2
       0       0 2ed2a3912a0b 000000000000 000000000000
  $ sl debugrename bar
  bar renamed from foo:2ed2a3912a0b24502043eae84ee4b279c18b90dd

  $ echo bleah > foo
  $ echo quux > bar
  $ sl commit -m3

should not be renamed
  $ sl debugrename bar
  bar not renamed

  $ sl copy -f foo bar
should show copy
  $ sl st -C
  M bar
    foo

  $ sl commit -m3

should show no parents for tip
  $ sl debugindex bar
     rev linkrev nodeid       p1           p2
       0       1 7711d36246cc 000000000000 000000000000
       1       2 bdf70a2b8d03 7711d36246cc 000000000000
       2       3 b2558327ea8d 000000000000 000000000000
should match
  $ sl debugindex foo
     rev linkrev nodeid       p1           p2
       0       0 2ed2a3912a0b 000000000000 000000000000
       1       2 dd12c926cf16 2ed2a3912a0b 000000000000
  $ sl debugrename bar
  bar renamed from foo:dd12c926cf165e3eb4cf87b084955cb617221c17

should show no copies
  $ sl st -C

copy --mark on an added file
  $ cp bar baz
  $ sl add baz
  $ sl cp --mark bar baz
  $ sl st -C
  A baz
    bar

foo was clean:
  $ sl st -AC foo
  C foo
Trying to copy on top of an existing file fails,
  $ sl copy --mark bar foo
  foo: not overwriting - file already committed
  (use 'sl copy --amend --mark' to amend the current commit)
same error without the --mark, so the user doesn't have to go through
two hints:
  $ sl copy bar foo
  foo: not overwriting - file already committed
  (use 'sl copy --amend --mark' to amend the current commit)
but it's considered modified after a copy --mark --force (legacy behavior)
  $ sl copy --mark -f bar foo
  $ sl st -AC foo
  M foo
    bar
  $ sl uncopy foo
  $ sl st -AC foo
  C foo
The hint for a file that exists but is not in file history doesn't
mention --force:
  $ touch xyzzy
  $ sl cp bar xyzzy
  xyzzy: not overwriting - file exists
  (sl copy --mark to record the copy)

test amend current commit
  $ sl go -Cq .
  $ sl clean --files
  $ mv foo foo2
  $ sl rm foo
  $ sl add foo2
  $ sl ci -m 'mv foo foo2'
  $ sl mv --mark foo foo2
  foo: $ENOENT$
  abort: no files to copy
  (use '--amend --mark' if you want to amend the current commit)
  [255]
  $ sl mv --amend --mark foo foo2
  $ sl st -C --change .
  A foo2
    foo
  R foo

  $ cd ..
