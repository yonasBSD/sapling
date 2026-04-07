
#require no-eden


Testing diff --change

  $ newclientrepo a

  $ echo "first" > file.txt
  $ sl add file.txt
  $ sl commit -m 'first commit' # 0
  $ sl push -q -r . --to head0 --create

  $ echo "second" > file.txt
  $ sl commit -m 'second commit' # 1

  $ echo "third" > file.txt
  $ sl commit -m 'third commit' # 2

  $ sl diff --nodates --change 'desc(second)'
  diff -r 4bb65dda5db4 -r e9b286083166 file.txt
  --- a/file.txt
  +++ b/file.txt
  @@ -1,1 +1,1 @@
  -first
  +second

  $ sl diff --change e9b286083166
  diff -r 4bb65dda5db4 -r e9b286083166 file.txt
  --- a/file.txt	Thu Jan 01 00:00:00 1970 +0000
  +++ b/file.txt	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,1 @@
  -first
  +second
  $ sl push -q -r . --to book --create

Test dumb revspecs: top-level "x:y", "x:", ":y" and ":" ranges should be handled
as pairs even if x == y, but not for "f(x:y)" nor "x::y" (issue3474, issue4774)

  $ newclientrepo dumbspec a_server book
  $ echo "wdir" > file.txt

  $ sl diff -r 'desc(third)':'desc(third)'
  $ sl diff -r 'desc(third)':.
  $ sl diff -r 'desc(third)':
  $ sl diff -r :'desc(first)'
  $ sl diff -r 'desc(third):first(desc(third):desc(third))'
  $ sl diff -r 'first(desc(third):desc(third))' --nodates
  diff -r bf5ff72eb7e0 file.txt
  --- a/file.txt
  +++ b/file.txt
  @@ -1,1 +1,1 @@
  -third
  +wdir
  $ sl diff -r '(desc(third):desc(third))' --nodates
  diff -r bf5ff72eb7e0 file.txt
  --- a/file.txt
  +++ b/file.txt
  @@ -1,1 +1,1 @@
  -third
  +wdir
  $ sl diff -r 'desc(third)'::'desc(third)' --nodates
  diff -r bf5ff72eb7e0 file.txt
  --- a/file.txt
  +++ b/file.txt
  @@ -1,1 +1,1 @@
  -third
  +wdir
  $ sl diff -r "desc(third) and desc(second)"
  abort: empty revision range
  [255]

  $ newclientrepo dumbspec-rev0 a_server book head0
  $ sl up -q head0
  $ echo "wdir" > file.txt

  $ sl diff -r 'first(:)' --nodates
  diff -r 4bb65dda5db4 file.txt
  --- a/file.txt
  +++ b/file.txt
  @@ -1,1 +1,1 @@
  -first
  +wdir

  $ cd ..

Testing diff --change when merge:

  $ cd a

  $ for i in 1 2 3 4 5 6 7 8 9 10; do
  >    echo $i >> file.txt
  > done
  $ sl commit -m "lots of text" # 3

  $ sed -e 's,^2$,x,' file.txt > file.txt.tmp
  $ mv file.txt.tmp file.txt
  $ sl commit -m "change 2 to x" # 4

  $ sl up -r 'desc(lots)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sed -e 's,^8$,y,' file.txt > file.txt.tmp
  $ mv file.txt.tmp file.txt
  $ sl commit -m "change 8 to y"

  $ sl up -C -r 273b50f17c6deb75b5a8652e5a9ca30bab9d8e40
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl merge -r 'max(desc(change))'
  merging file.txt
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl commit -m "merge 8 to y" # 6

  $ sl diff --change 'max(desc(change))'
  diff -r ae119d680c82 -r 9085c5c02e52 file.txt
  --- a/file.txt	Thu Jan 01 00:00:00 1970 +0000
  +++ b/file.txt	Thu Jan 01 00:00:00 1970 +0000
  @@ -6,6 +6,6 @@
   5
   6
   7
  -8
  +y
   9
   10

must be similar to 'sl diff --change 5':

  $ sl diff -c 'desc(merge)'
  diff -r 273b50f17c6d -r 979ca961fd2e file.txt
  --- a/file.txt	Thu Jan 01 00:00:00 1970 +0000
  +++ b/file.txt	Thu Jan 01 00:00:00 1970 +0000
  @@ -6,6 +6,6 @@
   5
   6
   7
  -8
  +y
   9
   10

  $ cd ..
