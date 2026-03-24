#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ . "$TESTDIR/library.sh"
  $ . "$TESTDIR/infinitepush/library.sh"
  $ setupcommon

Setup server
  $ newserver repo
  $ cd ..

Create client
  $ sl clone ssh://user@dummy/repo client -q
  $ cd client

Backup with remotenames enabled. Make sure that it works fine with anon heads
  $ mkcommit remotenamespush
  $ sl cloud backup
  commitcloud: head 'f4ca5164f72e' hasn't been uploaded yet
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
