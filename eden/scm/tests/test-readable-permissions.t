
#require no-eden



  $ export HGIDENTITY=sl
  $ newclientrepo repo
  $ echo a > a
  $ sl ci -Amq a

Test that we don't accidentally write non-readable files.
  $ find . -not -perm -0444
