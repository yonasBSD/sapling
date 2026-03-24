
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ shorttraceback
  $ newrepo
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS

  $ sl up -q $B

Dirstate rebuild should work with a broken dirstate

Broken by having an incomplete p2

  $ enable blackbox
# Assign to 'x' to hide the return value output in Python 3
  >>> x = open('.sl/dirstate', 'a').truncate(25)
  $ sl debugrebuilddirstate
  warning: failed to inspect working copy parent
  $ sl log -r . -T '{desc}\n'
  B

Broken by deleting the tree

  $ rm -rf .sl/treestate
  $ sl debugrebuilddirstate
  warning: failed to inspect working copy parent
  warning: failed to inspect working copy parent (?)
  $ sl log -r . -T '{desc}\n'
  B

Dirstate rebuild should work with sparse

  $ enable sparse
  $ sl sparse -I A
  $ rm .sl/dirstate
  $ sl debugrebuilddirstate -r $B
  $ sl log -r . -T '{desc}\n'
  B
