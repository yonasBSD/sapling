
#require symlink no-eden

  $ export HGIDENTITY=sl
  $ configure modern
  $ setconfig workingcopy.rust-checkout=true

  $ newserver server1
  $ clone server1 client

  $ cd client
  $ echo 'CONTENT' > file
  $ ln -s file link
  $ sl commit -qAm "first commit"
  $ sl rm link
  $ echo 'NO LONGER A LINK' > link
  $ sl commit -qAm "second"
  $ sl prev
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [7e5b26] first commit
  $ sl next
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [3165d5] second
  $ cat link
  NO LONGER A LINK
  $ cat file
  CONTENT

Make sure we can clear out unknown symlink to write regular file.
  $ mkdir subdir
  $ echo subfile > subdir/subfile
  $ sl commit -qAm subfile
  $ rm -rf subdir
  $ ln -s file subdir
Sanity that we can't do it without -C
  $ sl up -q .
  $ cat subdir/subfile
  cat: subdir/subfile: $ENOTDIR$
  [1]
  $ sl up -Cq .
  $ cat subdir/subfile
  subfile
