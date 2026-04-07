
We only expand globs on Windows.
#require windows no-eden

  $ newclientrepo
  $ touch foo foo2 bar
  $ sl st 'foo*'
  ? foo
  ? foo2
