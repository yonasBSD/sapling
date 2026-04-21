
#require eden

Make sure we can clone at a non-ascii mount path.

  $ newrepo repo
  $ drawdag <<EOS
  > B
  > |
  > A
  > EOS

test eden clone to a path with non-ASCII characters

  $ cd
#if windows
  $ sl clone -q test:repo test_你好 2>&1 | grep Error
   Stderr: 'Failed to clone. Error from EdenFS: class cpptoml::parse_exception: * could not be opened for parsing\r (esc) (glob)
#else
  $ sl clone -q test:repo test_你好
#endif
