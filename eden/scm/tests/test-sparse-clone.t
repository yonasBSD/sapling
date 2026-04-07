
#require no-eden

#inprocess-hg-incompatible
  $ setconfig clone.use-rust=1 commands.force-rust=clone

test sparse

  $ setconfig ui.username="nobody <no.reply@fb.com>"
  $ enable sparse rebase

  $ newremoterepo repo1
  $ setconfig paths.default=test:e1
  $ echo a > index.html
  $ echo x > data.py
  $ echo z > readme.txt
  $ cat > webpage.sparse <<EOF
  > [include]
  > *.html
  > EOF
  $ cat > backend.sparse <<EOF
  > [include]
  > *.py
  > EOF
  $ sl ci -Aqm 'initial'
  $ sl push -r . --to master --create -q

Verify local clone with a sparse profile works

  $ cd $TESTTMP
  $ sl clone --enable-profile webpage.sparse test:e1 clone1
  Cloning * into $TESTTMP/clone1 (glob)
  Checking out 'master'
  1 files updated
  $ cd clone1
  $ ls
  index.html
  $ cd ..

Verify sparse clone with a non-existing sparse profile warns

  $ SL_LOG=workingcopy=warn sl clone --enable-profile nonexisting.sparse test:e1 clone5
  Cloning * into $TESTTMP/clone5 (glob)
  Checking out 'master'
   WARN workingcopy::sparse: non-existent sparse profile include repo_path=RepoPathBuf("nonexisting.sparse")
   WARN workingcopy::sparse: non-existent sparse profile include repo_path=RepoPathBuf("nonexisting.sparse")
  5 files updated
  $ cd clone5
  $ ls
  backend.sparse
  data.py
  index.html
  readme.txt
  webpage.sparse
  $ cd ..

Verify that configured sparse profiles are enabled on clone

  $ cd $TESTTMP
  $ sl clone --enable-profile webpage.sparse test:e1 --config clone.additional-sparse-profiles.backend="backend.sparse" clone6
  Cloning * into $TESTTMP/clone6 (glob)
  Checking out 'master'
  2 files updated
  $ cd clone6
  $ ls
  data.py
  index.html
  $ cd ..

  $ cd $TESTTMP
  $ sl clone test:e1 --config clone.additional-sparse-profiles.backend="backend.sparse" clone7
  Cloning * into $TESTTMP/clone7 (glob)
  Checking out 'master'
  1 files updated
  $ cd clone7
  $ ls
  data.py
  $ cd ..
