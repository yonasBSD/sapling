#modern-config-incompatible
#inprocess-hg-incompatible


  $ configure dummyssh
#require serve no-eden

  $ sl init test
  $ cd test

  $ echo foo>foo
  $ sl addremove
  adding foo
  $ sl commit -m 1
  $ sl book master

  $ sl verify
  warning: verify does not actually check anything in this repo

  $ cd ..

  $ sl clone -q ssh://user@dummy/test copy

  $ cd copy
  $ sl verify
  commit graph passed quick local checks
  (pass --dag to perform slow checks with server)

  $ sl co tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat foo
  foo

  $ sl manifest --debug
  2ed2a3912a0b24502043eae84ee4b279c18b90dd 644   foo

  $ sl pull
  pulling from ssh://user@dummy/test

Test pull of non-existing 20 character revision specification, making sure plain ascii identifiers
not are encoded like a node:

  $ sl pull -r 'xxxxxxxxxxxxxxxxxxxy'
  pulling from ssh://user@dummy/test
  abort: unknown revision 'xxxxxxxxxxxxxxxxxxxy'!
  [255]
  $ sl pull -r 'xxxxxxxxxxxxxxxxxx y'
  pulling from ssh://user@dummy/test
  abort: unknown revision 'xxxxxxxxxxxxxxxxxx y'!
  [255]

Issue622: sl init && sl pull -u URL doesn't checkout default branch

  $ cd ..
  $ sl init empty
  $ cd empty
  $ sl pull -u ../test -d tip
  pulling from ../test
  adding changesets
  adding manifests
  adding file changes
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

Test 'file:' uri handling:

  $ sl pull -q file://../test-does-not-exist
  abort: file:// URLs can only refer to localhost
  [255]

  $ sl pull -q file://../test
  abort: file:// URLs can only refer to localhost
  [255]

MSYS changes 'file:' into 'file;'

#if no-msys
  $ sl pull -q file:../test  # no-msys
#endif

It's tricky to make file:// URLs working on every platform with
regular shell commands.

  $ URL=`sl debugshell -c "import os; ui.write('file://foobar' + ('/' + os.getcwd().replace(os.sep, '/')).replace('//', '/') + '/../test')"`
  $ sl pull -q "$URL"
  abort: file:// URLs can only refer to localhost
  [255]

  $ URL=`sl debugshell -c "import os; ui.write('file://localhost' + ('/' + os.getcwd().replace(os.sep, '/')).replace('//', '/') + '/../test')"`
  $ sl pull -q "$URL"

