
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
  UnicodeEncodeError: 'charmap' codec can't encode characters in position *: character maps to *\r (esc) (glob)
#else
  $ sl clone -q test:repo test_你好
#endif
