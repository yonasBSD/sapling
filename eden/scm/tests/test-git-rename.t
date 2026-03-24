#require git no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ . $TESTDIR/git.sh
  $ setconfig diff.git=True

Prepare repo

  $ sl init --git repo1
  $ cd repo1
  $ echo 1 >> a
  $ sl ci -q -Am 'add a'

Test mv

  $ sl mv a b
  $ sl ci -Am 'mv a -> b'
  $ sl diff -r.~1 -r .
  diff --git a/a b/b
  rename from a
  rename to b
