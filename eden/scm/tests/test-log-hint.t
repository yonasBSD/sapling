
#require no-eden


  $ export HGIDENTITY=sl
  $ setconfig tweakdefaults.logdefaultfollow=true

  $ newclientrepo
  $ drawdag <<EOS
  > B
  > |
  > A
  > EOS
  $ sl go -q $B

  $ sl log tip
  abort: cannot follow file not in parent revision: "tip"
  (did you mean "sl log -r 'tip'", or "sl log -r 'tip' -f" to follow history?)
  [255]

  $ sl log -r 'tip'
  commit:      112478962961
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     B

  $ sl log -r 'tip' -f
  commit:      112478962961
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     B
  
  commit:      426bada5c675
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     A
