#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo

Path conflict checking is currently disabled by default because of issue5716.
Turn it on for this test.

  $ setconfig experimental.merge.checkpathconflicts=True
  $ setconfig checkout.use-rust=true

  $ sl init repo
  $ cd repo
  $ echo base > base
  $ sl add base
  $ sl commit -m "base"
  $ sl bookmark -i base
  $ echo 1 > a
  $ sl add a
  $ sl commit -m "file"
  $ sl bookmark -i file
  $ echo 2 > a
  $ sl commit -m "file2"
  $ sl bookmark -i file2
  $ sl up -q 'desc(base)'
  $ mkdir a
  $ echo 2 > a/b
  $ sl add a/b
  $ sl commit -m "dir"
  $ sl bookmark -i dir

Basic merge - local file conflicts with remote directory

  $ sl up -q file
  $ sl bookmark -i
  $ sl merge --verbose dir
  resolving manifests
  a: path conflict - a file or link has the same name as a directory
  the local file has been renamed to a~853701544ac3
  resolve manually then use 'sl resolve --mark a'
  moving a to a~853701544ac3
  getting a/b
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ sl goto --clean .
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ rm a~853701544ac3

Basic update - local directory conflicts with remote file

  $ sl up -q 'desc(base)'
  $ mkdir a
  $ echo 3 > a/b
  $ sl up file
  abort: 1 conflicting file changes:
   a/b
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up --clean file
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark file)

Repo state is ok

  $ sl sum
  parent: 853701544ac3 
   file
  bookmarks: *file
  commit: (clean)
  phases: 4 draft

Basic update - untracked file conflicts with remote directory

  $ sl up -q 'desc(base)'
  $ echo untracked > a
  $ sl up dir
  abort: 1 conflicting file changes:
   a
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]

Basic clean update - local directory conflicts with changed remote file

  $ sl up -q file
  abort: 1 conflicting file changes:
   a
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ rm a
  $ mkdir a
  $ echo 4 > a/b
  $ sl up file2
  abort: 1 conflicting file changes:
  (current process runs with uid 42) (?)
  ($TESTTMP/repo/a: mode 0o52, uid 42, gid 42) (?)
  ($TESTTMP/repo: mode 0o52, uid 42, gid 42) (?)
   a/b
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up --clean file2
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark file2)

Repo state is ok

  $ sl sum
  parent: f64e09fac717 
   file2
  bookmarks: *file2
  commit: (clean)
  phases: 4 draft
