
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable journal undo rebase

  $ newrepo
  $ drawdag <<'EOS'
  > G K
  > :/
  > E
  > |\
  > C D
  > |/
  > B
  > |
  > A
  > EOS

  $ sl go $A -q
  $ sl go $D -q

  $ sl go -
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  A

  $ sl go -
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  D

  $ sl go $C -q
  $ sl go -
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  D

test merge commit

  $ sl go $E -q
  $ sl go -
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  D

  $ sl go -
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  E

test undo commands

  $ echo 1 >> x
  $ sl ci -Aqm X
  $ sl log -r . -T '{desc}\n'
  X
  $ sl undo -q
  $ sl log -r . -T '{desc}\n'
  E
  $ sl go -
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  X

test amend command
  $ sl go $D -q
  $ sl go $K -q
  $ echo 1 >> K
  $ sl amend
  $ sl go -
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  D

test amend & restack commands

  $ sl go $D -q
  $ sl go $F -q
  $ echo 1 >> F
  $ sl amend
  hint[amend-restack]: descendants of 8059b7e18560 are left behind - use 'sl restack' to rebase them
  hint[hint-ack]: use 'sl hint --ack amend-restack' to silence these hints
  $ sl rebase --restack
  rebasing bffd6b0484a3 "G"
  $ sl go -
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -r . -T '{desc}\n'
  D
