#require no-eden

Some Windows dummy ssh issue
#inprocess-hg-incompatible

  $ . "$TESTDIR/library.sh"

  $ setconfig push.edenapi=true

Setup lfs
  $ setconfig remotefilelog.lfs=true
  $ setconfig lfs.threshold=10B lfs.url="file:$TESTTMP/dummy-remote/"

Setup server repo
  $ sl init repo
  $ cd repo
  $ echo 1 > 1
  $ sl add 1
  $ sl ci -m initial
  $ sl bookmark master

Setup client
  $ cd ..
  $ sl clone ssh://user@dummy/repo client -q
  $ cd client
  $ echo aaaaaaaaaaa > largefile
  $ sl ci -Aqm commit

  $ sl push -q -r . --to lfscommit --create

  $ cd ..

Setup another client
  $ sl clone ssh://user@dummy/repo client2 -q
  $ cd client2
  $ sl pull -B lfscommit
  pulling from ssh://user@dummy/repo
  searching for changes
  $ sl goto remote/lfscommit
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

Make pushbackup that contains bundle with 2 heads
  $ cd ../client
  $ sl up -q tip
  $ mkcommit newcommit
  $ sl prev -q
  [0da81a] commit
  $ mkcommit newcommit2
  $ sl cloud backup
  commitcloud: head '5f9d85f9e1c6' hasn't been uploaded yet
  commitcloud: head 'c800524c1b76' hasn't been uploaded yet
  edenapi: queue 2 commits for upload
  edenapi: queue 2 files for upload
  edenapi: uploaded 2 files
  edenapi: queue 2 trees for upload
  edenapi: uploaded 2 trees
  edenapi: uploaded 2 changesets
  $ sl cloud check -r .
  c800524c1b7637c6f3f997d1459237d01fe1ea10 backed up

Pull just one head to trigger rebundle
  $ cd ../client2
  $ sl pull -r c800524c1b7637c6f3f997d1459237d01fe1ea10
  pulling from ssh://user@dummy/repo
  searching for changes
