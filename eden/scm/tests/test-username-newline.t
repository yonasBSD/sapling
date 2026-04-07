
#require no-eden


  $ sl init repo
  $ cd repo
  $ touch a

  $ unset HGUSER
  $ echo "[ui]" >> .sl/config
  $ echo "username= foo" >> .sl/config
  $ echo "          bar1" >> .sl/config

  $ sl ci -Am m
  adding a
  abort: username 'foo\nbar1' contains a newline
  
  [255]
  $ rm .sl/config

  $ HGUSER=`(echo foo; echo bar2)` sl ci -Am m
  adding a
  abort: username 'foo\nbar2' contains a newline
  
  [255]
  $ sl ci -Am m -u "`(echo foo; echo bar3)`"
  adding a
  abort: username 'foo\nbar3' contains a newline!
  [255]

