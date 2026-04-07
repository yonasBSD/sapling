#require no-eden

  $ sl init test
  $ cd test
  $ echo foo>foo
  $ sl addremove
  adding foo
  $ sl commit -m "1"

  $ sl verify
  warning: verify does not actually check anything in this repo

  $ sl clone . ../branch
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd ../branch
  $ sl co tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo bar>>foo
  $ sl commit -m "2"
  $ sl whereami
  30aff43faee11c21aa9036768ad78cc32a171e06

  $ cd ../test

  $ sl pull ../branch -r 30aff43faee11c21aa9036768ad78cc32a171e06
  pulling from ../branch
  searching for changes
  adding changesets
  adding manifests
  adding file changes

  $ sl verify
  warning: verify does not actually check anything in this repo

  $ sl co tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cat foo
  foo
  bar

  $ sl manifest --debug
  6f4310b00b9a147241b071a60c28a650827fb03d 644   foo

update to rev 0 with a date

  $ sl upd -d foo 0
  abort: you can't specify a revision and a date
  [255]

  $ cd ..

update with worker processes

#if no-windows

  $ cat <<EOF > forceworker.py
  > from sapling import extensions, worker
  > def nocost(orig, ui, costperop, nops):
  >     return worker._numworkers(ui) > 1
  > def uisetup(ui):
  >     extensions.wrapfunction(worker, 'worthwhile', nocost)
  > EOF

  $ sl init worker
  $ cd worker
  $ cat <<EOF >> .sl/config
  > [extensions]
  > forceworker = $TESTTMP/forceworker.py
  > [worker]
  > numcpus = 4
  > EOF
  $ for i in `seq 1 100`; do
  >   echo $i > $i
  > done
  $ sl ci -qAm 'add 100 files'

  $ sl goto null
  0 files updated, 0 files merged, 100 files removed, 0 files unresolved
  $ sl goto tip
  100 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd ..

#endif
