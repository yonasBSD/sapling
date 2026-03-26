#modern-config-incompatible

#require no-eden

  $ export HGIDENTITY=sl
  $ setconfig experimental.nativecheckout=true
  $ newserver server

  $ newremoterepo repo

  $ touch a
  $ sl add a
  $ sl commit -m "Added a"

  $ touch main
  $ sl add main
  $ sl commit -m "Added main"
  $ sl checkout c2eda428b523117ba9bbdfbbef034bb4bc8fead9
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

'main' should be gone:

  $ ls
  a

  $ touch side1
  $ sl add side1
  $ sl commit -m "Added side1"
  $ touch side2
  $ sl add side2
  $ sl commit -m "Added side2"

  $ sl log
  commit:      91ebc10ed028
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added side2
  
  commit:      b932d7dbb1e1
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added side1
  
  commit:      71a760306caf
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added main
  
  commit:      c2eda428b523
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added a
  

  $ sl heads
  commit:      91ebc10ed028
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added side2
  
  commit:      71a760306caf
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Added main
  
  $ ls
  a
  side1
  side2

  $ sl goto -C 71a760306cafb582ff672db4d4beb9625f34022d
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

  $ ls
  a
  main

