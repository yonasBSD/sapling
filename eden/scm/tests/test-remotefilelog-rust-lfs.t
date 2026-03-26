
#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo

  $ . "$TESTDIR/library.sh"

  $ newserver master
  $ clone master shallow
  $ cd shallow
  $ setconfig remotefilelog.lfs=True lfs.threshold=10B lfs.url=file:$TESTTMP/lfs

  $ printf 'THIS IS A BINARY LFS BLOB\0' > blob

  $ sl commit -qAm lfs1

  $ echo 'THIS IS ANOTHER LFS BLOB' > blob
  $ sl commit -qAm lfs2

  $ printf 'THIS IS A BINARY LFS BLOB\0' > blob
  $ sl commit -qAm lfs3

  $ findfilessorted .sl/store/lfs
  .sl/store/lfs/objects/8f/942761dd32573780723b14df5e401224674aa5ac58ef9f1df275f0c561433b
  .sl/store/lfs/objects/f3/8ef89300956a8cf001746d6e4b015708c3d0d883d1a69bf00f4958090cbe21
  .sl/store/lfs/pointers/index2-node
  .sl/store/lfs/pointers/index2-sha256
  .sl/store/lfs/pointers/lock (?)
  .sl/store/lfs/pointers/log
  .sl/store/lfs/pointers/meta
  .sl/store/lfs/pointers/rlock

# Blobs shouldn't have changed
  $ sl diff -r . -r .~2

# Remove the blobs
  $ rm -rf .sl/store/lfs/blobs

# With the backing blobs gone, diff should not complain about missing blobs
  $ sl diff -r . -r .~2
