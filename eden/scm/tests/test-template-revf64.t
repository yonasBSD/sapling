
#require no-eden

#inprocess-hg-incompatible

  $ configure modern

  $ newrepo
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS

Without revf64compat, rev is not in f64 safe range:

  $ setconfig experimental.revf64compat=0
  $ sl log -r $A -T '{rev}\n'
  72057594037927936

With revf64compat, rev is mapped to f64 safe range:

  $ setconfig experimental.revf64compat=1
  $ sl log -r $B -T '{rev}\n'
  281474976710657
  $ sl log -r $B -T json | grep rev
    "rev": 281474976710657,
  $ sl log -Gr $B -T '{rev}\n'
  o  281474976710657
  │
  ~
  $ sl log -Gr $B -T json | grep rev
  ~    "rev": 281474976710657,
  $ sl tip -T '{rev}\n'
  281474976710657
  $ sl tip -Tjson | grep rev
    "rev": 281474976710657,

Both the original and the mapped revs can be resolved just fine:

  $ sl log -r 72057594037927936+281474976710657 -T '{desc}\n'
  A
  B

The pattern "ifcontains(rev, revset('.'), ...)" can still be used:

  $ sl up -q $B
  $ sl log -r . -T "{ifcontains(rev, revset('.'), '@', 'o')}\n"
  @
