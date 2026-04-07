#require no-eden

#inprocess-hg-incompatible

Issue586: removing remote files after merge appears to corrupt the
dirstate

  $ newserver a
  $ echo a > a
  $ sl ci -Ama
  adding a
  $ sl book master

  $ cd
  $ sl clone -qU test:a b
  $ cd b
  $ echo b > b
  $ sl ci -Amb
  adding b

  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl rm -f a
  $ sl ci -Amc

  $ sl st -A
  C b
  $ cd ..

Issue1433: Traceback after two unrelated pull, two move, a merge and
a commit (related to issue586)

create test repos

  $ sl init repoa
  $ touch repoa/a
  $ sl -R repoa ci -Am adda
  adding a
  $ sl -R repoa whereami
  7132ab4568acf5245eda3a818f5e927761e093bd

  $ sl init repob
  $ touch repob/b
  $ sl -R repob ci -Am addb
  adding b
  $ sl -R repob whereami
  5ddceb3496526eca9300ea4b56d384785a1e31ba

  $ sl init repoc
  $ cd repoc
  $ sl pull -fr 7132ab456 ssh://user@dummy/repoa
  pulling from ssh://user@dummy/repoa
  adding changesets
  adding manifests
  adding file changes
  $ sl goto tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ mkdir tst
  $ sl mv * tst
  $ sl ci -m "import a in tst"
  $ sl pull -fr 5ddceb349 ../repob
  pulling from ../repob
  searching for changes
  warning: repository is unrelated
  adding changesets
  adding manifests
  adding file changes

merge both repos

  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ mkdir src

move b content

  $ sl mv b src
  $ sl ci -m "import b in src"
  $ sl manifest
  src/b
  tst/a

  $ cd ..
