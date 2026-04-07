#require no-eden

  $ newserver server
  $ cd $TESTTMP/server
  $ echo base > base
  $ sl commit -Aqm base
  $ sl bookmark master

  $ clone server client1
  $ sl --cwd client1 log -Gr 'all()' -T '{desc} {phase} {remotebookmarks}'
  @  base public remote/master
  

  $ clone server client2
  $ sl --cwd client2 log -Gr 'all()' -T '{desc} {phase} {remotebookmarks}'
  @  base public remote/master
  

Advance master

  $ cd $TESTTMP/server
  $ echo more >> base
  $ sl commit -Aqm public1

Pull in client1

  $ cd $TESTTMP/client1
  $ sl pull -q
  $ drawdag << 'EOS'
  > X
  > |
  > desc(base)
  > EOS
  $ sl cloud sync -q
  $ sl log -Gr 'all()' -T '{desc} {phase} {remotebookmarks}'
  o  X draft
  │
  │ o  public1 public remote/master
  ├─╯
  @  base public
  

Advance master again.
  $ cd $TESTTMP/server
  $ echo more >> base
  $ sl commit -Aqm public2

Sync in client2. The master bookmark gets synced to the same location as in
client1, but not in the server.

  $ cd $TESTTMP/client2
  $ sl cloud sync -q
  $ sl log -Gr 'all()' -T '{desc} {phase} {remotebookmarks}'
  o  X draft
  │
  │ o  public1 public remote/master
  ├─╯
  @  base public
  

Make changes in client2 and sync the changes to cloud.

  $ drawdag << 'EOS'
  > Y
  > |
  > desc(X)
  > EOS
  $ sl cloud sync -q

Sync back to client1. This does not cause lagged remote/master.

  $ cd $TESTTMP/client1
  $ sl cloud sync -q
  $ sl log -Gr 'all()' -T '{desc} {phase} {remotebookmarks}'
  o  Y draft
  │
  o  X draft
  │
  │ o  public1 public remote/master
  ├─╯
  @  base public
  
