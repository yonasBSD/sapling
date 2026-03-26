
#require no-eden


  $ export HGIDENTITY=sl
  $ configure modern
  $ enable rebase

Simple case:
  $ newrepo simple
  $ drawdag << 'EOS'
  > d
  > | c
  > | |
  > | b
  > |/
  > a
  > EOS
  $ sl hide $c
  hiding commit a82ac2b38757 "c"
  1 changeset hidden
  $ sl log -G -T '{desc}'
  o  d
  │
  │ o  b
  ├─╯
  o  a
  $ sl goto $b
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl rebase -d $d
  rebasing 488e1b7e7341 "b"
  $ sl log -G -T '{desc}'
  @  b
  │
  o  d
  │
  o  a
