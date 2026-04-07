
#require no-eden


  $ enable sparse
  $ newclientrepo

Make sure things work with invalid sparse profile:
  $ mkdir foo
  $ echo bar > foo/bar
  $ sl commit -Aqm foo
  $ echo "%include foo/" > .sl/sparse
  $ sl status
