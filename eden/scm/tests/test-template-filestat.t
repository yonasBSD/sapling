
#require no-eden


  $ eagerepo
  $ newrepo
  $ touch base
  $ sl commit -Am A
  adding base
  $ echo somedata > base
  $ touch other
  $ sl commit -Am B
  adding other
  $ sl rm base
  $ echo somemoredata > other
  $ sl commit -m C

  $ sl log --graph -T '{filestat}'
  @  2 filestats
  │
  o  2 filestats
  │
  o  1 filestat
  
  $ sl log --graph -T '{filestat|json}'
  @  [{"name": "other", "op": "M", "size": 13, "type": "n"}, {"name": "base", "op": "R", "size": 0, "type": "r"}]
  │
  o  [{"name": "base", "op": "M", "size": 9, "type": "n"}, {"name": "other", "op": "A", "size": 0, "type": "n"}]
  │
  o  [{"name": "base", "op": "A", "size": 0, "type": "n"}]
  
  $ sl log -T '{filestat % "{node|short} {op} {type} {size} {name}\n"}'
  bdfc298dced0 M n 13 other
  bdfc298dced0 R r 0 base
  7f32e4a2ca03 M n 9 base
  7f32e4a2ca03 A n 0 other
  ca66854ba526 A n 0 base
#if no-windows
  $ chmod +x other
  $ ln -s other link
  $ sl commit -Am "D"
  adding link
  $ sl log --graph -T '{filestat}'
  @  2 filestats
  │
  o  2 filestats
  │
  o  2 filestats
  │
  o  1 filestat
  
  $ sl log --graph -T '{filestat|json}'
  @  [{"name": "other", "op": "M", "size": 13, "type": "x"}, {"name": "link", "op": "A", "size": 5, "type": "l"}]
  │
  o  [{"name": "other", "op": "M", "size": 13, "type": "n"}, {"name": "base", "op": "R", "size": 0, "type": "r"}]
  │
  o  [{"name": "base", "op": "M", "size": 9, "type": "n"}, {"name": "other", "op": "A", "size": 0, "type": "n"}]
  │
  o  [{"name": "base", "op": "A", "size": 0, "type": "n"}]
  
  $ sl log -T '{filestat % "{node|short} {op} {type} {size} {name}\n"}'
  8c2b56d0093b M x 13 other
  8c2b56d0093b A l 5 link
  bdfc298dced0 M n 13 other
  bdfc298dced0 R r 0 base
  7f32e4a2ca03 M n 9 base
  7f32e4a2ca03 A n 0 other
  ca66854ba526 A n 0 base
#endif
