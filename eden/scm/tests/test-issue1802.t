
#require execbit no-eden


Create extension that can disable exec checks:

  $ cat > noexec.py <<EOF
  > from sapling import extensions, util
  > def setflags(orig, f, l, x):
  >     pass
  > def checkexec(orig, path):
  >     return False
  > def extsetup(ui):
  >     extensions.wrapfunction(util, 'setflags', setflags)
  >     extensions.wrapfunction(util, 'checkexec', checkexec)
  > EOF

  $ newclientrepo unix-repo server
  $ touch a
  $ sl add a
  $ sl commit -m 'unix: add a'
  $ sl push -q -r . --to book --create
  $ newclientrepo win-repo server book
  $ cd ../unix-repo
  $ chmod +x a
  $ sl commit -m 'unix: chmod a'
  $ sl push -q -r . --to book --create
  $ sl manifest -v
  755 * a

  $ cd ../win-repo

  $ touch b
  $ sl add b
  $ sl commit -m 'win: add b'

  $ sl manifest -v
  644   a
  644   b

  $ sl pull -B book
  pulling from test:server
  searching for changes

  $ sl manifest -v -r book
  755 * a

Simulate a Windows merge:

  $ sl --config extensions.n=$TESTTMP/noexec.py merge --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: a03b0deabf2b, local: d6fa54f68ae1+, remote: 2d8bcf2dda39
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl debugtreestate list
  a: * EXIST_P1 EXIST_P2 EXIST_NEXT NEED_CHECK  (glob)
  b: * EXIST_P1 EXIST_NEXT * (glob)

Simulate a Windows commit:

"a" should be modified since p2 adds executable bit
  $ sl status
  M a

noexec.py is not needed for commit since Rust status doesn't check a's on-disk flags
in this case at all. The rust "pending changes" only checks with respect to p1.
Rust picks up the change by inference since the file is EXIST_P1 and EXIST_P2.
  $ sl commit -m 'merge'

  $ sl manifest -v
  755 * a
  644   b

  $ cd ..
