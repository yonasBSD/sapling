
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo

Tests the behavior of the DEFAULT_EXTENSIONS constant in extensions.py

  $ sl init a
  $ cd a

sl githelp works without enabling:

  $ sl githelp -- git checkout HEAD
  sl goto .

Behaves identically if enabled manually:

  $ sl githelp --config extensions.githelp= -- git checkout HEAD
  sl goto .

Not if turned off:
 (note: extension discovery only works for normal layout)

#if normal-layout
  $ sl githelp --config extensions.githelp=! -- git checkout HEAD
  unknown command 'githelp'
  (use 'sl help' to get help)
  [255]
#endif

Or overriden by a different path:

  $ cat > githelp2.py <<EOF
  > from __future__ import absolute_import
  > from sapling import registrar
  > 
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > 
  > @command('githelp')
  > def githhelp(ui, repo, *args, **opts):
  >      ui.warn('Custom version of sl githelp\n')
  > 
  > EOF
  $ sl githelp --config extensions.githelp=`pwd`/githelp2.py -- git checkout HEAD
  Custom version of sl githelp

A default extension's reposetup and extsetup are run:
  $ cd $TESTTMP
  $ mkdir ext
  $ cat > ext/mofunc.py <<EOF
  > from sapling.ext import githelp
  > def extsetup(ui):
  >     # Only print reposetup() once so that this test output doesn't change
  >     # the number of times repo gets wrapped as we enable extensions.
  >     githelp.reposetupcount = 0
  >     def reposetup(ui, repo):
  >         if githelp.reposetupcount == 0:
  >             ui.warn('githelp reposetup()\n')
  >         githelp.reposetupcount += 1
  >     def extsetup(ui):
  >         ui.warn('githelp extsetup()\n')
  >     githelp.reposetup = reposetup
  >     githelp.extsetup = extsetup
  > EOF
  $ sl -R a githelp --config extensions.path=ext/mofunc.py -- git status
  githelp extsetup()
  githelp reposetup()
  sl status
