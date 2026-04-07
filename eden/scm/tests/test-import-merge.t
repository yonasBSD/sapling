#require no-eden

  $ configure modernclient
  $ setconfig workingcopy.rust-checkout=true

  $ tipparents() {
  > sl parents --template "{node|short} {desc|firstline}\n" -r .
  > }

Test import and merge diffs

  $ newclientrepo repo server
  $ echo a > a
  $ sl ci -Am adda
  adding a
  $ echo a >> a
  $ sl ci -m changea
  $ echo c > c
  $ sl ci -Am addc
  adding c
  $ sl push -r . -q --to rev2 --create
  $ sl up 'desc(adda)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo b > b
  $ sl ci -Am addb
  adding b
  $ sl push -r . -q --to rev3 --create
  $ sl up 'desc(changea)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl merge 'desc(addb)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m merge
  $ sl export . > ../merge.diff
  $ grep -v '^merge$' ../merge.diff > ../merge.nomsg.diff
  $ newclientrepo repo2 server rev2
  $ sl pull -B rev3
  pulling from test:server
  searching for changes

Test without --exact and diff.p1 == workingdir.p1

  $ sl up 'desc(changea)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ cat > $TESTTMP/editor.sh <<EOF
  > env | grep HGEDITFORM
  > echo merge > \$1
  > EOF
  $ HGEDITOR="sh '$TESTTMP/editor.sh'" sl import --edit ../merge.nomsg.diff
  applying ../merge.nomsg.diff
  HGEDITFORM=import.normal.merge
  $ tipparents
  540395c44225 changea
  102a90ea7b4a addb
  $ sl hide -q -r .

Test without --exact and diff.p1 != workingdir.p1

  $ sl up 'desc(addc)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl import ../merge.diff
  applying ../merge.diff
  warning: import the patch as a normal revision
  (use --exact to import the patch as a merge)
  $ tipparents
  890ecaa90481 addc
  $ sl hide -q -r .

Test with --exact

  $ sl import --exact ../merge.diff
  applying ../merge.diff
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ tipparents
  540395c44225 changea
  102a90ea7b4a addb
  $ sl hide -q -r .

Test with --bypass and diff.p1 == workingdir.p1

  $ sl up 'desc(changea)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl import --bypass ../merge.diff -m 'merge-bypass1'
  applying ../merge.diff
  $ sl up -q 'desc("merge-bypass1")'
  $ tipparents
  540395c44225 changea
  102a90ea7b4a addb
  $ sl hide -q -r .

Test with --bypass and diff.p1 != workingdir.p1

  $ sl up 'desc(addc)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl import --bypass ../merge.diff -m 'merge-bypass2'
  applying ../merge.diff
  warning: import the patch as a normal revision
  (use --exact to import the patch as a merge)
  $ sl up -q 'desc("merge-bypass2")'
  $ tipparents
  890ecaa90481 addc
  $ sl hide -q -r .

  $ cd ..

Test that --exact on a bad header doesn't corrupt the repo (issue3616)

  $ newclientrepo repo3
  $ echo a>a
  $ sl ci -Aqm0
  $ sl push -q -r . --to rev0 --create
  $ echo a>>a
  $ sl ci -m1
  $ sl push -q -r . --to rev1 --create
  $ echo a>>a
  $ sl ci -m2
  $ echo a>a
  $ echo b>>a
  $ echo a>>a
  $ sl ci -m3
  $ sl export 'desc(2)' > $TESTTMP/p
  $ head -7 $TESTTMP/p > ../a.patch
  $ sl export tip > out
  >>> with open("../a.patch", "ab") as apatch:
  ...     _ = apatch.write(b"".join(open("out", "rb").readlines()[7:]))

  $ newclientrepo repor-clone repo3_server rev0
  $ sl pull -q -B rev1

  $ sl import --exact ../a.patch
  applying ../a.patch
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  patching file a
  Hunk #1 succeeded at 1 with fuzz 1 (offset -1 lines).
  abort: patch is damaged or loses information
  [255]
