
#require no-eden


  $ eagerepo
  $ newext adddrop <<EOF
  > from sapling import registrar
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command('debugadddrop',
  >   [('', 'drop', False, 'drop file from dirstate', 'FILE'),
  >    ('', 'normal-lookup', False, 'add file to dirstate', 'FILE')],
  >     'sl debugadddrop')
  > def debugadddrop(ui, repo, *pats, **opts):
  >   '''Add or drop unnamed arguments to or from the dirstate'''
  >   drop = opts.get('drop')
  >   nl = opts.get('normal_lookup')
  >   if nl and drop:
  >       raise error.Abort('drop and normal-lookup are mutually exclusive')
  >   wlock = repo.wlock()
  >   try:
  >     for file in pats:
  >       if opts.get('normal_lookup'):
  >         repo.dirstate.normallookup(file)
  >       else:
  >         repo.dirstate.untrack(file)
  > 
  >     repo.dirstate.write(repo.currenttransaction())
  >   finally:
  >     wlock.release()
  > EOF

basic test for sl debugrebuildstate

  $ sl init repo
  $ cd repo

  $ touch foo bar
  $ sl ci -Am 'add foo bar'
  adding bar
  adding foo

  $ touch baz
  $ sl add baz
  $ sl rm bar

  $ sl debugrebuildstate

state dump after

  $ sl debugstate --nodates | sort
  n   0         -1 unset               bar
  n   0         -1 unset               foo

  $ sl debugadddrop --normal-lookup file1 file2
  $ sl debugadddrop --drop bar
  $ sl debugadddrop --drop
  $ sl debugstate --nodates
  n   0         -1 unset               file1
  n   0         -1 unset               file2
  n   0         -1 unset               foo
  $ sl debugrebuildstate

status

# avoid same second race condition that leaves NEED_CHECK
  $ sleep 1

  $ sl st -A
  ! bar
  ? baz
  C foo

Make sure the second status call doesn't need to compare file contents anymore.
  $ LOG=workingcopy::filechangedetector=trace sl status 2>&1 | grep get_content | grep enter
  *compare contents{keys=0}* (glob)

Test debugdirstate --minimal where a file is not in parent manifest
but in the dirstate
  $ touch foo bar qux
  $ sl add qux
  $ sl remove bar
  $ sl status -A
  A qux
  R bar
  ? baz
  C foo
  $ sl debugadddrop --normal-lookup baz
  $ sl debugdirstate --nodates
  r   0          0 * bar (glob)
  n   0         -1 * baz (glob)
  n 644          0 * foo (glob)
  a   0         -1 * qux (glob)
  $ sl debugrebuilddirstate --minimal
  $ sl debugdirstate --nodates
  r   0          0 * bar (glob)
  n 644          0 * foo (glob)
  a   0         -1 * qux (glob)
  $ sl status -A
  A qux
  R bar
  ? baz
  C foo

Test debugdirstate --minimal where file is in the parent manifest but not the
dirstate
  $ sl manifest
  bar
  foo
  $ sl status -A
  A qux
  R bar
  ? baz
  C foo
  $ sl debugdirstate --nodates
  r   0          0 * bar (glob)
  n 644          0 * foo (glob)
  a   0         -1 * qux (glob)
  $ sl debugadddrop --drop foo
  $ sl debugdirstate --nodates
  r   0          0 * bar (glob)
  a   0         -1 * qux (glob)
  $ sl debugrebuilddirstate --minimal
  $ sl debugdirstate --nodates
  r   0          0 * bar (glob)
  n   0         -1 * foo (glob)
  a   0         -1 * qux (glob)
  $ sl status -A
  A qux
  R bar
  ? baz
  C foo

