#require git no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ . $TESTDIR/git.sh

Prepare repo

  $ sl init --git repo1
  $ cd repo1
  $ echo 'A--B' | drawdag
  $ sl up -q $B

Test uncommit

  $ enable amend
  $ sl uncommit

  $ sl st
  A B

  $ sl log -r. -T '{desc}\n'
  A

