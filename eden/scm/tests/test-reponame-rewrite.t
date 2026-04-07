#require no-eden

  $ configure modern
  $ setconfig remotefilelog.reponame=reponame-default
  $ newrepo

Make sure we do not rewrite by default:
  $ cat .sl/reponame
  reponame-default (no-eol)
  $ LOG=configloader::hg=debug sl log 2>&1 | grep written
  [1]

Rewrite on wrong reponame:
  $ echo foobar > .sl/reponame
  $ LOG=configloader::hg=debug sl log  2>&1 | grep written
  DEBUG configloader::hg: repo name: written to reponame file
  $ cat .sl/reponame
  reponame-default (no-eol)
