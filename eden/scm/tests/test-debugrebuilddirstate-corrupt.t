
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Setup

  $ sl init repo
  $ cd repo
  $ echo base > base
  $ sl add base
  $ sl commit -m "base"

Deliberately corrupt the dirstate.

  >>> with open('.sl/dirstate', 'wb') as f: f.write(b"\0" * 4096) and None

  $ sl debugrebuilddirstate
  warning: failed to inspect working copy parent
