#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
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
  $ echo z >> x
  $ sl commit -qAm z
  $ echo a > a
  $ sl commit -qAm a
  $ sl book master

  $ cd ..

  $ hgcloneshallow ssh://user@dummy/master shallow -q
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over *s (glob) (?)
  $ cd shallow

Test blame

  $ sl blame -c x
  b292c1e3311f: x
  66ee28d0328c: y
  16db62c5946f: z
  2 files fetched over 1 fetches - (2 misses, 0.00% hit ratio) over 0.00s (?)
