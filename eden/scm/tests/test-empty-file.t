
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo

  $ newclientrepo
  $ touch empty1
  $ sl add empty1
  $ sl commit -m 'add empty1'

  $ touch empty2
  $ sl add empty2
  $ sl commit -m 'add empty2'

  $ sl up -C 1e1d9c4e5b64028c36a7955c906c9a549cd0f523
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ touch empty3
  $ sl add empty3
  $ sl commit -m 'add empty3'

  $ sl heads
  commit:      a1cb177e0d44
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add empty3
  
  commit:      097d2b0e17f6
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add empty2
  

  $ sl merge 097d2b0e17f6a1d7bfe479e1992ca2a243d22563
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

Before changeset 05257fd28591, we didn't notice the
empty file that came from rev 1:

  $ sl status
  M empty2
  $ sl commit -m merge
  $ sl manifest --debug tip
  b80de5d138758541c5f05265ad144ab9fa86d1db 644   empty1
  b80de5d138758541c5f05265ad144ab9fa86d1db 644   empty2
  b80de5d138758541c5f05265ad144ab9fa86d1db 644   empty3

  $ cd ..
