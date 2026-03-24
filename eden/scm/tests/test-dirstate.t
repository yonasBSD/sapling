
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig format.dirstate=2

------ Test dirstate._dirs refcounting

  $ sl init t
  $ cd t
  $ mkdir -p a/b/c/d
  $ touch a/b/c/d/x
  $ touch a/b/c/d/y
  $ touch a/b/c/d/z
  $ sl ci -Am m
  adding a/b/c/d/x
  adding a/b/c/d/y
  adding a/b/c/d/z
  $ sl mv a z
  moving a/b/c/d/x to z/b/c/d/x
  moving a/b/c/d/y to z/b/c/d/y
  moving a/b/c/d/z to z/b/c/d/z

Test name collisions

  $ rm z/b/c/d/x
  $ mkdir z/b/c/d/x
  $ touch z/b/c/d/x/y
  $ sl add z/b/c/d/x/y
  abort: file 'z/b/c/d/x' in dirstate clashes with 'z/b/c/d/x/y'
  [255]
  $ rm -rf z/b/c/d
  $ touch z/b/c/d
  $ sl add z/b/c/d
  abort: directory 'z/b/c/d' already in dirstate
  [255]

  $ cd ..

Issue1790: dirstate entry locked into unset if file mtime is set into
the future

Prepare test repo:

  $ sl init u
  $ cd u
  $ echo a > a
  $ sl add
  adding a
  $ sl ci -m1

Test modulo storage/comparison of absurd dates:

#if no-aix
  $ touch -t 195001011200 a
  $ sl st
  $ sl debugstate
  n 644          2 2018-01-19 15:14:08 a
#endif

Verify that exceptions during a dirstate change leave the dirstate
coherent (issue4353)

  $ cat > ../dirstateexception.py <<EOF
  > from __future__ import absolute_import
  > from sapling import (
  >   dirstate,
  >   error,
  >   extensions,
  > )
  > 
  > def raiseerror(orig, *args, **opts):
  >     raise error.Abort("simulated error while recording dirstateupdates")
  > 
  > def reposetup(ui, repo):
  >     extensions.wrapfunction(dirstate.dirstate, 'setparents', raiseerror)
  > EOF

  $ sl rm a
  $ sl commit -m 'rm a'
  $ echo "[extensions]" >> .sl/config
  $ echo "dirstateex=../dirstateexception.py" >> .sl/config
  $ sl up 'desc(1)'
  abort: simulated error while recording dirstateupdates
  [255]
  $ sl log -r . -T '{node}\n'
  dfda8c2e7522c4207035f267703c5f27af5a5bf7
  $ sl status
  ? a
  $ rm .sl/config

Verify that status reports deleted files correctly
  $ sl add a
  $ rm a
  $ sl status
  ! a
  $ sl diff

Dirstate should block addition of paths with relative parent components
  $ sl up -C .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ ls
  $ sl debugsh -c "repo.dirstate.add('foo/../b')"
  abort: cannot add path with relative parents: foo/../b
  [255]
  $ touch b
  $ mkdir foo
  $ sl add foo/../b
  $ sl commit -m "add b"
  $ sl status --change .
  A b
