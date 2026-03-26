
#require no-eden



File to dir:

  $ export HGIDENTITY=sl
  $ newclientrepo
  $ echo A | drawdag
  $ sl up -q $A
  $ rm A
  $ mkdir -p A/A
  $ touch A/A/A
  $ sl revert .
  reverting A
  $ cat A
  A (no-eol)

File to parent dir:

  $ newclientrepo
  $ drawdag << 'EOS'
  > A  # A/D/D/D/1=1
  > EOS
  $ sl up -q $A
  $ rm -rf D/D
  $ echo 2 > D/D
  $ sl revert .
  reverting D/D/D/1
