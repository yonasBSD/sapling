
#require no-eden


  $ export HGIDENTITY=sl
  $ configure modern

  $ newext deprecatecmd <<EOF
  > from sapling import registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command('testdeprecate', [], 'sl testdeprecate')
  > def testdeprecate(ui, repo, level):
  >     ui.deprecate("test-feature", "blah blah message", int(level))
  > EOF

  $ sl init client
  $ cd client

  $ sl testdeprecate 0
  devel-warn: feature 'test-feature' is deprecated: blah blah message
   at: $TESTTMP/deprecatecmd.py:6 (testdeprecate)
  $ sl blackbox | grep deprecated
  * [legacy][deprecated] blah blah message (glob)
  * [legacy][develwarn] devel-warn: feature 'test-feature' is deprecated: blah blah message (glob)

  $ sl testdeprecate 1
  warning: feature 'test-feature' is deprecated: blah blah message
  note: the feature will be completely disabled soon, so please migrate off

  $ sl testdeprecate 2
  warning: sleeping for 2 seconds because feature 'test-feature' is deprecated: blah blah message
  note: the feature will be completely disabled soon, so please migrate off

  $ sl testdeprecate 3
  abort: feature 'test-feature' is disabled: blah blah message
  (set config `deprecated.bypass-test-feature=True` to temporarily bypass this block)
  [255]

  $ sl testdeprecate 3 --config deprecated.bypass-test-feature=True
  warning: feature 'test-feature' is deprecated: blah blah message
  note: the feature will be completely disabled soon, so please migrate off

  $ sl testdeprecate 4
  abort: feature 'test-feature' is disabled: blah blah message
  [255]

  $ sl testdeprecate 4 --config deprecated.bypass-test-feature=True
  abort: feature 'test-feature' is disabled: blah blah message
  [255]
