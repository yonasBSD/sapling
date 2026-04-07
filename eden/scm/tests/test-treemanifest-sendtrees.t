
#require no-eden



  $ . "$TESTDIR/library.sh"

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > pushrebase=
  > [treemanifest]
  > sendtrees=True
  > EOF

Setup the server

  $ hginit master
  $ cd master
  $ cat >> .sl/config <<EOF
  > [remotefilelog]
  > server=True
  > shallowtrees=True
  > EOF

Make local commits on the server
  $ mkdir subdir
  $ echo x > subdir/x
  $ sl commit -qAm 'add subdir/x'
  $ sl book master

The following will turn on sendtrees mode for a hybrid client and verify it
sends them during a push and during bundle operations.

Create flat manifest clients
  $ cd ..
  $ hgcloneshallow ssh://user@dummy/master client1 -q
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob) (?)
  $ hgcloneshallow ssh://user@dummy/master client2 -q

Transition to hybrid flat+tree client
  $ cat >> client1/.sl/config <<EOF
  > [extensions]
  > amend=
  > [treemanifest]
  > demanddownload=True
  > EOF
  $ cat >> client2/.sl/config <<EOF
  > [extensions]
  > amend=
  > [treemanifest]
  > demanddownload=True
  > EOF

Make a draft commit
  $ cd client1
  $ echo f >> subdir/x
  $ sl commit -qm "hybrid commit"
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.
Test bundling/unbundling
  $ sl bundle -r . --base '.^' ../treebundle.hg --debug 2>&1 | grep treegroup
  bundle2-output-part: "b2x:treegroup2" (params: 3 mandatory) streamed payload

  $ cd ../client2
  $ sl unbundle ../treebundle.hg --debug 2>&1 | grep treegroup
  bundle2-input-part: "b2x:treegroup2" (params: 3 mandatory) supported
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.
Test pushing
  $ sl push -r tip --to master --debug 2>&1 2>&1 | grep rebasepackpart
  bundle2-output-part: "b2x:rebasepackpart" (params: 3 mandatory) streamed payload
