
#require no-eden

  $ newclientrepo repo
  $ echo a > a
  $ sl ci -Am0
  adding a
  $ sl push -q -r . --to book --create

  $ newclientrepo foo repo_server book
  $ cd ../repo

Journal is cleaned up automatically.
  $ echo something > .sl/store/journal

  $ echo foo > a
  $ sl ci -Am0
  couldn't read journal entry 'something\n'!

  $ sl recover
  no interrupted transaction available
  [1]

Empty journal is cleaned up automatically.
  $ touch .sl/store/journal
  $ sl ci -Am0
  nothing changed
  [1]
