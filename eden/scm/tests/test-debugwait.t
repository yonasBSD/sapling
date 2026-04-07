
#require no-eden

#inprocess-hg-incompatible

  $ enable amend
  $ newrepo

  $ sl debugwait
  nothing to wait (see '--help')
  [1]

  $ sl debugwait --commits -n 1 > wait1.log &
  $ sl commit -m x --config ui.allowemptycommit=1
  $ wait
  $ cat wait1.log
  commits

  $ sl debugwait --commits --wdir-parents -n 2 > wait2.log &
  $ sl metaedit -m y
  $ wait
  $ sort wait2.log
  commits
  wdir-parents

  $ sl debugwait --commits --wdir-parents -n 1 > wait3.log &
  $ sl go -q null
  $ wait
  $ cat wait3.log
  wdir-parents

  $ sl debugwait --commits --wdir-parents --wdir-content -n 1 > ../wait4.log &
  $ touch a
  $ sl add a
  $ sl mv -q a b
  $ wait
  $ cat ../wait4.log
  wdir-content
