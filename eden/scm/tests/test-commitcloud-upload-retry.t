#require no-eden

  $ enable amend
  $ setconfig infinitepushbackup.hostname=testhost

  $ . "$TESTDIR/library.sh"
  $ . "$TESTDIR/infinitepush/library.sh"
  $ setupcommon

Enable retries with minimal backoff for a fast test.
  $ setconfig commitcloud.upload_retry_attempts=3
  $ setconfig commitcloud.upload_retry_base_backoff_ms=1
  $ setconfig commitcloud.upload_retry_max_backoff_ms=1

Setup server
  $ newserver repo
  $ setupserver
  $ cd ..

  $ sl clone ssh://user@dummy/repo client -q
  $ cd client
  $ mkcommit retry-me

Failpoint fires once then disables: first uploadchangesets call fails with a
500, retry succeeds. Without retry this would abort with [255].
  $ FAILPOINTS="eagerepo::api::uploadchangesets=1*return(error)" sl cloud backup
  commitcloud: head '*' hasn't been uploaded yet (glob)
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: queue 1 commit for upload
  edenapi: queue 0 files for upload
  edenapi: queue 0 trees for upload
  edenapi: uploaded 1 changeset

  $ sl cloud check -r .
  * backed up (glob)
