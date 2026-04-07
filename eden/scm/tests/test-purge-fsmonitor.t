#require fsmonitor no-eden

  $ newclientrepo repo
  $ touch x

Watchman clock is set after "status"

  $ sl status
  ? x
  $ sl debugshell -c 'ui.write("%s\n" % str(repo.dirstate.getclock()))'
  c:* (glob)

Watchman clock is not reset after a "purge --all"

  $ sl purge --all
  $ sl debugshell -c 'ui.write("%s\n" % str(repo.dirstate.getclock()))'
  c:* (glob)
  $ sl status
