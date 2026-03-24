
#require no-eden



  $ export HGIDENTITY=sl
  $ newclientrepo test1

Sample config item that has been moved from configitems.py to Rust HG_PY_CORE_CONFIG
  $ sl config ui.timeout
  600

  $ sl config ui.timeout --config ui.timeout=123
  123

  $ cat > $TESTTMP/test.rc <<EOF
  > [ui]
  > timeout=456
  > EOF
  $ sl config ui.timeout --config ui.timeout=123 --configfile $TESTTMP/test.rc
  123

  $ sl config ui.timeout --configfile $TESTTMP/test.rc
  456

  $ cat >> .sl/config <<EOF
  > [ui]
  > timeout=789
  > EOF
  $ sl config ui.timeout --configfile $TESTTMP/test.rc
  456

  $ sl config ui.timeout
  789

Make sure --config options are available when loading config itself.
"root" is not material - the important thing is that the regen-command is respected:

  $ echo > "$TESTTMP/test_hgrc"
  $ HG_TEST_INTERNALCONFIG="$TESTTMP/test_hgrc" LOG=configloader::hg=debug sl root --config "configs.regen-command=false" --config configs.generationtime=0 2>&1 | grep '^DEBUG.* spawn '
  DEBUG configloader::hg: spawn ["false"] because * (glob)

Only load config a single time.
  $ LOG=configloader::hg=info sl files abc
   INFO configloader::hg: loading config repo_path=* (glob)
  [1]

Only load config a single time when repo config file doesn't exist:
  $ ls .sl/config
  .sl/config
  $ rm .sl/config
  $ LOG=configloader::hg=info sl files abc --config paths.default=test:test1_server
   INFO configloader::hg: loading config repo_path=* (glob)
  [1]
