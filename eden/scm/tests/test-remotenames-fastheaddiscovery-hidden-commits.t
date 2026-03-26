#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ enable amend

Set up repositories

  $ sl init repo1
  $ sl clone -q repo1 repo2
  $ sl clone -q repo1 repo3

Set up the repos with a remote bookmark

  $ cd repo2
  $ echo a > a
  $ sl commit -Aqm commitA
  $ sl push -q --to book --create
  $ cd ..

  $ cd repo3
  $ sl pull -q -B book
  $ cd ..

Produce a new commit in repo2

  $ cd repo2
  $ echo b > b
  $ sl commit -Aqm commitB
  $ sl bundle -q -r . ../bundleB
  $ sl push -q --to book
  $ cd ..

Load the commit in repo3, hide it, check that we can still pull.

  $ cd repo3

  $ sl unbundle -q ../bundleB
  $ sl log -r tip -T '{desc}\n'
  commitB
  $ sl hide -q -r tip

  $ sl goto -q remote/book
  $ sl log -r tip -T '{desc}\n'
  commitB

  $ sl pull -q
  $ sl log -r "reverse(::book)" -T '{desc}\n'
  commitB
  commitA

  $ cd ..
