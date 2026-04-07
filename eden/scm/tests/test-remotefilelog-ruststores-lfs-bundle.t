#require no-eden

  $ setconfig remotefilelog.lfs=True
  $ setconfig lfs.threshold=5
  $ setconfig lfs.url=file:$TESTTMP/lfs-server

  $ newclientrepo

  $ echo "X" > x
  $ sl commit -qAm x
  $ echo "Y" > y
  $ echo "reallybig" > big
  $ sl commit -qAm y

  $ showgraph
  @  5b61e1ea02bb y
  │
  o  766002fed348 x

  $ sl bundle -r tip --base null ~/out.bundle
  2 changesets found

  $ newclientrepo
  $ sl unbundle ~/out.bundle
  adding changesets
  adding manifests
  adding file changes
  $ sl go -q 5b61e1ea02bb
  $ cat big
  reallybig
