
#require no-eden


  $ eagerepo
Testing that hghave does not crash when checking features

  $ sl debugpython -- $TESTDIR/hghave --test-features 2>/dev/null
