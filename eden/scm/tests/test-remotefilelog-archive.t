#modern-config-incompatible

#require no-eden


  $ . "$TESTDIR/library.sh"

  $ hginit master
  $ cd master
  $ cat >> .sl/config <<EOF
  > [remotefilelog]
  > server=True
  > EOF
  $ echo x > x
  $ sl commit -qAm x
  $ echo y >> x
  $ sl commit -qAm y
  $ mkdir dir
  $ echo z >> dir/z
  $ sl commit -qAm z
  $ echo z >> dir/z2
  $ sl commit -qAm z2
  $ sl book master

  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master shallow -q
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over 0.00s (?)
  $ cd shallow

Test blame

  $ clearcache
  $ sl archive -r tip -t tar myarchive.tar
  3 files fetched over 1 fetches - (3 misses, 0.00% hit ratio) over 0.00s (?)
