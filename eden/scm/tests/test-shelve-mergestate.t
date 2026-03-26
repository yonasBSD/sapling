  $ export HGIDENTITY=sl
  $ enable morestatus shelve
  $ setconfig morestatus.show=true
  $ setconfig ui.interactive=true

# shelve -i and make sure it does not result into an unfinished merge state
  $ newclientrepo
  $ mkdir foo && cd foo
  $ echo '1\n2\n3\n4\n5\n' > a
  $ sl ci -Aqm a
  $ echo '11\n2\n3\n4\n55\n' > a

  $ sl shelve -i  <<EOF
  > y
  > y
  > n
  > EOF
  diff --git a/foo/a b/foo/a
  2 hunks, 2 lines changed
  examine changes to 'foo/a'? [Ynesfdaq?] y
  
  @@ -1,4 +1,4 @@
  -1
  +11
   2
   3
   4
  record change 1/2 to 'foo/a'? [Ynesfdaq?] y
  
  @@ -2,5 +2,5 @@
   2
   3
   4
  -5
  +55
   
  record change 2/2 to 'foo/a'? [Ynesfdaq?] n
  
  shelved as default
  merging a
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved

  $ sl st
  M a

  $ sl diff
  diff -r f7e2aa31a34b foo/a
  --- a/foo/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/foo/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -2,5 +2,5 @@
   2
   3
   4
  -5
  +55
   
