
#require no-eden


Test avoiding calculating head changes during commit

  $ export HGIDENTITY=sl
  $ sl init branchatcommit
  $ cd branchatcommit
  $ sl debugdrawdag<<'EOS'
  > B
  > |
  > A
  > EOS
  $ sl up -q A
  $ echo C > C
  $ sl commit -m C -A C
  $ sl up -q A
  $ echo D > D
  $ sl commit -m D -A D

