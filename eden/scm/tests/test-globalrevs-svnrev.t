
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable commitextras
  $ enable globalrevs

  $ newrepo

Test with a valid svnrev

  $ echo data > file
  $ sl add file
  $ sl commit -m "foo" --extra "convert_revision=svn:1234/foo/trunk/bar@4567"
  $ sl log -T '{globalrev}\n' -r .
  4567

Test with an invalid svnrev

  $ echo moredata > file
  $ sl commit -m "foo" --extra "convert_revision=111111"
  $ sl log -T '{globalrev}\n' -r .
  
