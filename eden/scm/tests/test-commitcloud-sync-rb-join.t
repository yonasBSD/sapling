#require no-eden

  $ showgraph() {
  >    sl log -G -T "{desc}: {phase} {bookmarks} {remotenames}" -r "all()"
  > }

  $ newserver server
  $ cd $TESTTMP/server
  $ echo base > base
  $ sl commit -Aqm base
  $ echo 1 > public1
  $ sl commit -Aqm public1
  $ sl bookmark master

  $ cd $TESTTMP
  $ clone server client1
  $ cd client1
  $ sl up -q remote/master
  $ sl cloud sync -q
  $ showgraph
  @  public1: public  remote/master
  │
  o  base: public
  

  $ cd $TESTTMP
  $ cd server
  $ echo 2 > public2
  $ sl commit -Aqm public2

  $ cd $TESTTMP
  $ clone server client2
  $ cd client2
  $ sl up -q remote/master
  $ sl cloud sync -q
  $ showgraph
  @  public2: public  remote/master
  │
  o  public1: public
  │
  o  base: public
  

  $ cd $TESTTMP
  $ cd client1
  $ sl cloud sync -q
  $ showgraph
  o  public2: public  remote/master
  │
  @  public1: public
  │
  o  base: public
  

  $ echo 1 > file
  $ sl commit -Aqm draft1
  $ sl cloud sync -q

  $ cd $TESTTMP
  $ cd client2
  $ sl cloud sync -q
  $ showgraph
  o  draft1: draft
  │
  │ @  public2: public  remote/master
  ├─╯
  o  public1: public
  │
  o  base: public
  
