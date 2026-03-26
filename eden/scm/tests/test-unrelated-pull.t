#modern-config-incompatible

#require no-eden

#inprocess-hg-incompatible


  $ export HGIDENTITY=sl
  $ sl init a
  $ cd a
  $ echo 123 > a
  $ sl add a
  $ sl commit -m "a" -u a
  $ sl book master

  $ cd ..
  $ sl init b
  $ cd b
  $ echo 321 > b
  $ sl add b
  $ sl commit -m "b" -u b

  $ sl pull ../a
  pulling from ../a
  searching for changes
  abort: repository is unrelated
  [255]

  $ sl pull -f ../a
  pulling from ../a
  searching for changes
  warning: repository is unrelated
  adding changesets
  adding manifests
  adding file changes

  $ sl heads
  commit:      9a79c33a9db3
  user:        a
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  
  commit:      01f8062b2de5
  user:        b
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  

  $ cd ..
