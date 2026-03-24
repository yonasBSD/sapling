
#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo

Setup repo:
  $ newclientrepo
  $ drawdag << 'EOS'
  > G # bookmark master = G
  > |
  > F
  > |
  > E
  > |
  > D
  > |
  > C
  > |
  > B
  > |
  > A
  > EOS
  $ sl log -T "{node}\n"
  43195508e3bb704c08d24c40375bdd826789dd72
  a194cadd16930608adaa649035ad4c16930cbd0f
  9bc730a19041f9ec7cb33c626e811aa233efb18c
  f585351a92f85104bff7c284233c338b10eb1df7
  26805aba1e600a82e93661149f2313866a221a7b
  112478962961147124edd43549aedd1a335e44bf
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0

Test hash prefix lookup:
  $ sl debugrevset 431
  43195508e3bb704c08d24c40375bdd826789dd72
  $ sl debugrevset 4
  abort: ambiguous identifier for '4': 426bada5c67598ca65036d57d9e4b64b0c1ce7a0, 43195508e3bb704c08d24c40375bdd826789dd72 available
  [255]
  $ sl debugrevset 6
  abort: unknown revision '6'
  [255]
  $ sl debugrevset thisshóuldnótbéfoünd
  abort: unknown revision 'thissh*' (glob)
  [255]

Test bookmark lookup
  $ sl book -r 'desc(C)' mybookmark
  $ sl debugrevset mybookmark
  26805aba1e600a82e93661149f2313866a221a7b

Test remote bookmark lookup
  $ sl debugrevset master
  43195508e3bb704c08d24c40375bdd826789dd72

Test dot revset lookup
  $ sl debugrevset .
  0000000000000000000000000000000000000000
  $ sl debugrevset ""
  0000000000000000000000000000000000000000
  $ sl up 43195508e3
  7 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl debugrevset .
  43195508e3bb704c08d24c40375bdd826789dd72
  $ sl debugrevset ""
  43195508e3bb704c08d24c40375bdd826789dd72

Test misc revsets
  $ sl debugrevset tip
  43195508e3bb704c08d24c40375bdd826789dd72
  $ sl debugrevset null
  0000000000000000000000000000000000000000

Test resolution priority
  $ sl book -r 'desc(A)' f
  $ sl debugrevset f
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0
  $ sl debugrevset tip
  43195508e3bb704c08d24c40375bdd826789dd72
  $ sl debugrevset null
  0000000000000000000000000000000000000000


Test remote/lazy hash prefix lookup:
  $ newrepo remote
  $ drawdag << 'EOS'
  > C # bookmark master = C
  > |
  > B
  > |
  > A
  > EOS
  $ sl log -T "{node}\n"
  26805aba1e600a82e93661149f2313866a221a7b
  112478962961147124edd43549aedd1a335e44bf
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0

  $ newclientrepo client remote

  $ sl debugrevset 426bada5c67598ca65036d57d9e4b64b0c1ce7a0
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0

  $ sl debugrevset zzzbada5c67598ca65036d57d9e4b64b0c1ce7a0
  abort: unknown revision 'zzzbada5c67598ca65036d57d9e4b64b0c1ce7a0'
  [255]

  $ sl debugrevset 11
  112478962961147124edd43549aedd1a335e44bf


Fall back to changelog if "tip" isn't available in metalog:
  $ newclientrepo
  $ sl debugrevset tip
  0000000000000000000000000000000000000000
  $ drawdag << 'EOS'
  > A
  > EOS
  $ sl dbsh -c 'del ml["tip"]; ml.commit("no tip")'
  $ sl dbsh -c 'print(ml["tip"] or "no tip")'
  no tip
  $ sl debugrevset tip
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0
Don't propagate a bad ml "tip":
  $ sl dbsh -c 'ml["tip"] = bin("112478962961147124edd43549aedd1a335e44bf"); ml.commit("bad tip")'
  $ sl debugrevset tip
  426bada5c67598ca65036d57d9e4b64b0c1ce7a0
