#require no-eden

  $ setconfig remotefilelog.cachelimit=50B remotefilelog.manifestlimit=50B

  $ newserver master
  $ sl debugdetectissues
  ran issue detector 'cachesizeexceedslimit', found 0 issues
  $ echo "a" > a ; sl add a ; sl commit -qAm a
  $ echo "b" > b ; sl add b ; sl commit -qAm b
  $ sl debugdetectissues
  ran issue detector 'cachesizeexceedslimit', found 0 issues
  $ cd ..
  $ clone master shallow
  $ cd shallow
  $ sl debugdetectissues
  ran issue detector 'cachesizeexceedslimit', found 2 issues
  'cache_size_exceeds_limit': 'cache size of * exceeds configured limit of 50. 0 files skipped.' (glob)
  'manifest_size_exceeds_limit': 'manifest cache size of * exceeds configured limit of 50. 0 files skipped.' (glob)
