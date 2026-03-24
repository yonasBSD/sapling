
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
https://bz.mercurial-scm.org/1877

  $ sl init a
  $ cd a
  $ echo a > a
  $ sl add a
  $ sl ci -m 'a'
  $ echo b > a
  $ sl ci -m'b'
  $ sl up 'desc(a)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl book main
  $ sl book
   * main                      cb9a9f314b8b
  $ echo c > c
  $ sl add c
  $ sl ci -m'c'
  $ sl book
   * main                      d36c0562f908
  $ sl heads
  commit:      d36c0562f908
  bookmark:    main
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  commit:      1e6c11564562
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  $ sl up 1e6c11564562
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark main)
  $ sl merge main
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl book
     main                      d36c0562f908
  $ sl ci -m'merge'
  $ sl book
     main                      d36c0562f908

  $ cd ..
