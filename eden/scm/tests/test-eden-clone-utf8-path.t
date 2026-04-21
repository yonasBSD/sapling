
#require eden

Make sure we can clone at a non-ascii mount path.

  $ newrepo repo
  $ drawdag <<EOS
  > B  # bookmark master = B
  > |
  > A
  > EOS

test eden clone to a path with non-ASCII characters

  $ cd
  $ sl -q clone test:repo test_你好
  $ ls test_你好
  A
  B
