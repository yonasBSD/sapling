
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ newrepo
  $ setconfig diff.git=1 diff.hashbinary=1

  >>> _ = open('a.bin', 'wb').write(b'\0\1')
  $ sl commit -m A -A a.bin

  >>> _ = open('a.bin', 'wb').write(b'\0\2')

  $ sl diff
  diff --git a/a.bin b/a.bin
  Binary file a.bin has changed to 9ac521e32f8e19473bc914e1af8ae423a6d8c122

  $ HGPLAIN=1 sl diff
  diff --git a/a.bin b/a.bin
  Binary file a.bin has changed to 9ac521e32f8e19473bc914e1af8ae423a6d8c122

  $ HGPLAIN=1 HGPLAINEXCEPT=diffopts sl diff
  diff --git a/a.bin b/a.bin
  Binary file a.bin has changed to 9ac521e32f8e19473bc914e1af8ae423a6d8c122

  $ sl rm a.bin -f

  $ sl diff
  diff --git a/a.bin b/a.bin
  deleted file mode 100644
  Binary file a.bin has changed

  $ HGPLAIN=1 sl diff
  diff --git a/a.bin b/a.bin
  deleted file mode 100644
  Binary file a.bin has changed

  $ HGPLAIN=1 HGPLAINEXCEPT=diffopts sl diff
  diff --git a/a.bin b/a.bin
  deleted file mode 100644
  Binary file a.bin has changed
