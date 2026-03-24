
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable crdump

  $ showgraph() {
  >    sl log -G -T "{desc}: {phase} {bookmarks} {remotenames}" -r "all()"
  > }

Setup server

  $ sl init server
  $ cd server
  $ drawdag <<EOS
  > Y
  > |
  > X
  > EOS
  $ sl bookmark -r $X bookmark1
  $ sl bookmark -r $X bookmark1.1
  $ sl bookmark -r $Y bookmark2

Setup client

  $ cd $TESTTMP
  $ clone server client
  $ cd client
  $ sl pull -B bookmark1 -B bookmark2 -B bookmark1.1
  pulling from test:server
  $ sl goto -r bookmark1 -q
  $ echo 1 >> a
  $ sl ci -Am a
  adding a

  $ showgraph
  @  a: draft
  │
  │ o  Y: public  remote/bookmark2
  ├─╯
  o  X: public  remote/bookmark1 remote/bookmark1.1

#if jq
  $ sl debugcrdump -r . | jq '.commits[].branch'
  "bookmark1"
#endif
