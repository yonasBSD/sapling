#chg-compatible
#debugruntest-incompatible


  $ . "$TESTDIR/library.sh"

  $ enable lfs pushrebase
  $ hginit master

  $ cd master
  $ setconfig remotefilelog.server=True remotefilelog.shallowtrees=True
  $ mkdir dir
  $ echo x > dir/x
  $ sl commit -qAm x1
  $ sl book master
  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master shallow
  1 files fetched over 1 fetches - (1 misses, 0.00% hit ratio) over * (glob) (?)
  fetching lazy changelog
  populating main commit graph
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd shallow
  $ setconfig treemanifest.sendtrees=True
  $ echo >> dir/x
  $ sl commit -m "Modify dir/x"
  $ sl push --to master
  pushing rev 6b73ab2c9773 to destination ssh://user@dummy/master bookmark master
  searching for changes
  updating bookmark master
  remote: pushing 1 changeset:
  remote:     6b73ab2c9773  Modify dir/x
  $ sl --cwd ../master log -G -l 1 --stat
  o  commit:      6b73ab2c9773
  │  bookmark:    master
  ~  user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     Modify dir/x
  
      dir/x |  1 +
      1 files changed, 1 insertions(+), 0 deletions(-)
  
