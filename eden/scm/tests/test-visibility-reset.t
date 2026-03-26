
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable amend rebase reset
  $ setconfig experimental.evolution=obsolete
  $ setconfig visibility.enabled=true
  $ setconfig mutation.record=true mutation.enabled=true

  $ newrepo
  $ drawdag << EOS
  > E F
  > |/
  > C D
  > |/
  > B
  > |
  > A
  > EOS
  $ sl up -q $E
  $ sl bookmark test-bookmark
  $ tglogm
  o  ee481a2a1e69 'F'
  │
  │ @  78d2dca436b2 'E' test-bookmark
  ├─╯
  │ o  be0ef73c17ad 'D'
  │ │
  o │  26805aba1e60 'C'
  ├─╯
  o  112478962961 'B'
  │
  o  426bada5c675 'A'
  
  $ sl reset -C $D
  2 changesets hidden

Note that reset tried to hide 'C', but this was ignored because of 'F'.

  $ tglogm
  o  ee481a2a1e69 'F'
  │
  │ @  be0ef73c17ad 'D' test-bookmark
  │ │
  o │  26805aba1e60 'C'
  ├─╯
  o  112478962961 'B'
  │
  o  426bada5c675 'A'
  
