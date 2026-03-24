#require fsmonitor icasefs no-eden

(Run this test using HGFSMONITOR_TESTS=1)

Updating across a rename

  $ export HGIDENTITY=sl
  $ newclientrepo

  $ echo >> a
  $ sl commit -Aqm "add a"
  $ sl mv a A
  $ sl commit -qm "move a to A"
  $ sl up -q '.^'
  $ sl status
