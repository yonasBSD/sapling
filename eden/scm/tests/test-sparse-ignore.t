
#require no-eden

  $ eagerepo
  $ enable sparse
  $ newrepo
  $ sl sparse include src
  $ mkdir src
  $ touch src/x
  $ sl commit -m x -A src/x

The root directory ("") should not be ignored

  $ sl debugshell -c 'ui.write("%s\n" % str(repo.dirstate._ignore.visitdir("")))'
  True
