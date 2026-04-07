#require fsmonitor linux
#debugruntest-incompatible

  $ configure modernclient
  $ newclientrepo repo

sl status on a non-utf8 filename
  $ touch foo
  $ python3 -c 'open(b"\xc3\x28", "wb+").write(b"asdf")'
  $ sl status --traceback
  skipping * filename: '*' (glob)
  ? foo
