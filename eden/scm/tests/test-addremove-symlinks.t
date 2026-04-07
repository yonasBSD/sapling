#require symlink no-eden

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ mkdir foo
  $ touch foo/file
  $ sl commit -m one -A
  adding foo/file
  $ mkdir bar
  $ touch bar/file
  $ rm -rf foo
  $ ln -s bar foo
  $ sl addremove
  adding bar/file
  adding foo
  removing foo/file

Don't get confused by foo/file reapparing behind the symlink.
  $ sl addremove
