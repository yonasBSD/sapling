
#require no-eden


  $ export HGIDENTITY=sl
  $ configure modern

"import" can revive a commit

  $ newrepo

  $ drawdag <<'EOS'
  > B
  > |
  > A
  > EOS

  $ sl export $B > $TESTTMP/b.patch

  $ sl hide -q $B
  $ sl log -r 'all()' -T '{desc}\n'
  A

  $ sl up -q $A
  $ sl import -q --exact $TESTTMP/b.patch
  $ sl log -r 'all()' -T '{desc}\n'
  A
  B

"commit" can revive a commit

  $ newrepo

  $ sl commit --config ui.allowemptycommit=1 -m A

  $ sl hide -q .
  $ sl log -r 'all()' -T '{desc}\n'

  $ sl commit --config ui.allowemptycommit=1 -m A
  $ sl log -r 'all()' -T '{desc}\n'
  A

