#modern-config-incompatible

#require no-eden

#chg-compatible


  $ . "$TESTDIR/library.sh"


  $ hginit master
  $ cd master
  $ cat >> .sl/config <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ sl commit -qAm 'add x'
  $ sl book master
  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master client -q --noupdate
  $ cd client

Test autocreatetrees
  $ cat >> .sl/config <<EOF
  > [treemanifest]
  > autocreatetrees=True
  > EOF
  $ cd ../master
  $ mkdir subdir
  $ echo z >> subdir/z
  $ sl commit -qAm 'add subdir/z'

  $ cd ../client
  $ sl pull -q

  $ sl up -r 'desc("add subdir/z")'
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over * (glob) (?)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.

Test that commit creates local trees
  $ echo z >> subdir/z
  $ sl commit -qAm 'modify subdir/z'
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.


Test that manifest matchers work
  $ sl status --rev 'desc("add subdir/z")' --rev 'desc("modify subdir/z")' -I subdir/a
  $ sl status --rev 'desc("add subdir/z")' --rev 'desc("modify subdir/z")' -I subdir/z
  M subdir/z

Test rebasing a stack of commits results in a pack with all the trees

  $ echo >> subdir/y
  $ sl commit -qAm 'modify subdir/y'
  $ echo >> subdir/y
  $ sl commit -Am 'modify subdir/y again'
  $ sl rebase -d 085784c01c08984ae3b6f4e4a6e553035d58380b -s '.^'
  rebasing * "modify subdir/y" (glob)
  rebasing * "modify subdir/y again" (glob)
  $ sl log -r '.^::.' -T '{manifest}\n'
  0e5087e257eeb8a1418a1ec5f4395fb17b8c1b4f
  ba4fcc53f7c9ac6201325aed3e64b83905bd5784
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.

Test treemanifest with sparse enabled
  $ cat >> .sl/config <<EOF
  > [extensions]
  > sparse=
  > reset=
  > EOF
  $ sl sparse -I subdir
  $ sl reset '.^'
  1 changeset hidden
  $ sl status
  M subdir/y
  $ sl up -C .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl sparse --reset

Test rebase two commits with same changes
  $ echo >> subdir/y
  $ sl commit -qm 'modify subdir/y #1'
  $ sl up -q '.^'
  $ echo >> x
  $ echo >> subdir/y
  $ sl commit -qm 'modify subdir/y #2'
  $ sl up -q '.^'
  $ echo >> noop
  $ sl add noop
  $ sl commit -Am 'rebase destination'
  $ sl rebase -d 'desc(rebase)' -r 'desc("#1")' -r 'desc("#2")' --config rebase.singletransaction=True
  rebasing * "modify subdir/y #1" (glob)
  rebasing * "modify subdir/y #2" (glob)
TODO(meyer): Fix debugindexedlogdatastore and debugindexedloghistorystore and add back output here.
