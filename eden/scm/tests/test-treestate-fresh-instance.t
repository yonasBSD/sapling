#require fsmonitor no-eden

  $ setconfig format.dirstate=2
  $ newclientrepo repo
  $ touch x
  $ sl status
  ? x
  $ sl debugshell --command 'print(repo.dirstate.getclock())'
  c:* (glob)

Change the clock to an invalid value

  $ sl debugshell --command 'with repo.wlock(), repo.lock(), repo.transaction("dirstate") as tr: repo.dirstate.setclock("c:11111:22222"); repo.dirstate.write(tr)'
  $ sl debugshell --command 'print(repo.dirstate.getclock())'
  c:11111:22222

Run "sl status" again. A new clock value will be written even if no files are changed

  $ sl status
  ? x
  $ sl debugshell --command 'print(repo.dirstate.getclock() != "c:11111:22222")'
  True
