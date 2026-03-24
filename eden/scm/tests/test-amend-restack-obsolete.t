
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ configure mutation-norecord
  $ enable amend rebase
  $ setconfig rebase.experimental.inmemory=True
  $ setconfig rebase.singletransaction=True
  $ setconfig amend.autorestack=no-conflict
  $ mkcommit() {
  >   echo "$1" > "$1"
  >   hg add "$1"
  >   hg ci -m "add $1"
  > }

Test invalid value for amend.autorestack
  $ newrepo
  $ sl debugdrawdag<<'EOS'
  >    D
  >    |
  > C  C_old
  > |  |      # amend: B_old -> B
  > B  B_old  # amend: C_old -> C
  > | /
  > |/
  > A
  > EOS
  $ sl goto -qC B
  $ echo "new content" > B
  $ showgraph
  o  3c36beb5705f D
  │
  │ o  26805aba1e60 C
  │ │
  x │  07863d11c289 C_old
  │ │
  │ @  112478962961 B
  │ │
  x │  3326d5194fc9 B_old
  ├─╯
  o  426bada5c675 A
  $ sl amend -m "B'"
  restacking children automatically (unless they conflict)
  rebasing 26805aba1e60 "C" (C)
  $ showgraph
  o  5676eb48a524 C
  │
  @  180681c3ccd0 B'
  │
  │ o  3c36beb5705f D
  │ │
  │ x  07863d11c289 C_old
  │ │
  │ x  3326d5194fc9 B_old
  ├─╯
  o  426bada5c675 A
  $ sl rebase --restack
  rebasing 3c36beb5705f "D" (D)
  $ showgraph
  o  d1e904d06977 D
  │
  o  5676eb48a524 C
  │
  @  180681c3ccd0 B'
  │
  o  426bada5c675 A
