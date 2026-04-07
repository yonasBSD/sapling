
#require no-eden


Path conflict checking is currently disabled by default because of issue5716.
Turn it on for this test.

  $ setconfig checkout.use-rust=true
  $ setconfig experimental.merge.checkpathconflicts=True

  $ sl init repo
  $ cd repo
  $ echo base > base
  $ sl add base
  $ sl commit -m "base"
  $ sl bookmark -i base
  $ mkdir a
  $ echo 1 > a/b
  $ sl add a/b
  $ sl commit -m "file"
  $ sl bookmark -i file
  $ echo 2 > a/b
  $ sl commit -m "file2"
  $ sl bookmark -i file2
  $ sl up 'desc(base)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ mkdir a
#if symlink
  $ ln -s c a/b
#else
  $ touch a/b
#endif
  $ sl add a/b
  $ sl commit -m "link"
  $ sl bookmark -i link
  $ sl up 'desc(base)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ mkdir -p a/b/c
  $ echo 2 > a/b/c/d
  $ sl add a/b/c/d
  $ sl commit -m "dir"
  $ sl bookmark -i dir

Update - local file conflicts with remote directory:

  $ sl up -q 'desc(base)'
  $ mkdir a
  $ echo 9 > a/b
  $ sl up dir
  abort: 1 conflicting file changes:
   a/b
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up dir --config experimental.checkout.rust-path-conflicts=false
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark dir)

Update - local symlink conflicts with remote directory:

  $ sl up -q 'desc(base)'
  $ mkdir a
#if symlink
  $ ln -s x a/b
#else
  $ touch a/b
#endif
  $ sl up dir
  abort: 1 conflicting file changes:
   a/b
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up dir --config experimental.checkout.rust-path-conflicts=false
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark dir)

Update - local directory conflicts with remote file

  $ sl up -q 'desc(base)'
  $ mkdir -p a/b/c
  $ echo 9 > a/b/c/d
  $ sl up file
  abort: 1 conflicting file changes:
   a/b/c/d
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up file --config experimental.checkout.rust-path-conflicts=false
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark file)
  $ cat a/b
  1

Update - local directory conflicts with remote symlink

  $ sl up -q 'desc(base)'
  $ mkdir -p a/b/c
  $ echo 9 > a/b/c/d
  $ sl up link
  abort: 1 conflicting file changes:
   a/b/c/d
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up link --config experimental.checkout.rust-path-conflicts=false
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark link)
#if symlink
  $ f a/b
  a/b -> c
#endif

Update - local renamed file conflicts with remote directory

  $ sl up -q 'desc(base)'
  $ sl mv base a
  $ sl status -C
  A a
    base
  R base
  $ sl up --check dir
  abort: uncommitted changes
  [255]
  $ sl up dir --merge
  a: path conflict - a file or link has the same name as a directory
  the local file has been renamed to a~d20a80d4def3
  resolve manually then use 'sl resolve --mark a'
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  (activating bookmark dir)
  [1]
  $ sl status -C
  A a~d20a80d4def3
    base
  R base
  $ sl resolve --list
  P a
  $ sl up --clean -q 'desc(base)'

Update clean - local directory conflicts with changed remote file

  $ sl up -q file
  $ rm a/b
  $ mkdir a/b
  $ echo 9 > a/b/c
  $ sl up file2 --check --config experimental.checkout.rust-path-conflicts=false
  abort: uncommitted changes
  [255]
  $ sl up file2 --clean
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (changing active bookmark from file to file2)
