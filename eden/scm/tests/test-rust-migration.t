
#require no-eden


  $ eagerepo
  $ setconfig edenapi.url=https://test_fail/foo
  $ sl init testrepo
  $ cd testrepo

Test failed fallback
  $ sl --config commands.force-rust=clone clone -u yadayada aoeu snth
  [197]
  $ sl --config commands.force-rust=config config commands.force-rust -T "*shrugs*"
  [197]
  $ touch something
  $ sl addremove
  adding something
  $ sl commit -m "Added something"
  $ sl --config commands.force-rust=status st 'set:added()'
  [197]
