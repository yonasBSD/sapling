
#require no-eden

# Portions Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Copyright (c) Mercurial Contributors.

  $ setconfig hint.ack-match-full-traversal=true
  $ sl init repo
  $ cd repo
  $ echo 0 > a
  $ echo 0 > b
  $ echo 0 > t.h
  $ mkdir t
  $ echo 0 > t/x
  $ echo 0 > t/b
  $ echo 0 > t/e.h
  $ mkdir dir.h
  $ echo 0 > dir.h/foo

  $ sl ci -A -m 'initial'
  adding a
  adding b
  adding dir.h/foo
  adding t.h
  adding t/b
  adding t/e.h
  adding t/x

  $ touch nottracked

  $ sl locate a
  a

  $ sl locate NONEXISTENT
  [1]

  $ sl locate
  a
  b
  dir.h/foo
  t.h
  t/b
  t/e.h
  t/x

  $ sl rm a
  $ sl ci -m 'remove a'

  $ sl locate a
  [1]
  $ sl locate NONEXISTENT
  [1]
  $ sl locate 'relpath:NONEXISTENT'
  [1]
  $ sl locate
  b
  dir.h/foo
  t.h
  t/b
  t/e.h
  t/x
  $ sl locate -r 'desc(initial)' a
  a
  $ sl locate -r 'desc(initial)' NONEXISTENT
  [1]
  $ sl locate -r 'desc(initial)' 'relpath:NONEXISTENT'
  [1]
  $ sl locate -r 'desc(initial)'
  a
  b
  t.h
  dir.h/foo
  t/b
  t/e.h
  t/x

# -I/-X with relative path should work:

  $ cd t
  $ sl locate
  b
  dir.h/foo
  t.h
  t/b
  t/e.h
  t/x
  $ sl locate -I ../t
  t/b
  t/e.h
  t/x

# Issue294: sl remove dir fails when dir.* also exists

  $ cd ..
  $ rm -r t

  $ sl rm t/b

  $ sl locate 't/**'
  t/b
  t/e.h
  t/x

  $ sl files
  b
  dir.h/foo
  t.h
  t/e.h
  t/x
  $ sl files b
  b

  $ mkdir otherdir
  $ cd otherdir

  $ sl files 'path:'
  ../b
  ../dir.h/foo
  ../t.h
  ../t/e.h
  ../t/x
  $ sl files 'path:.'
  ../b
  ../dir.h/foo
  ../t.h
  ../t/e.h
  ../t/x

  $ sl locate b
  ../b
  ../t/b
  $ sl locate '*.h'
  ../t.h
  ../t/e.h
  $ sl locate 'path:t/x'
  ../t/x
  $ sl locate 're:.*\.h$'
  ../t.h
  ../t/e.h
  $ sl locate -r 'desc(initial)' b
  ../b
  ../t/b
  $ sl locate -r 'desc(initial)' '*.h'
  ../t.h
  ../t/e.h
  $ sl locate -r 'desc(initial)' 'path:t/x'
  ../t/x
  $ sl locate -r 'desc(initial)' 're:.*\.h$'
  ../t.h
  ../t/e.h

  $ sl files
  ../b
  ../dir.h/foo
  ../t.h
  ../t/e.h
  ../t/x
  $ sl files .
  [1]

# Convert native path separator to slash (issue5572)

  $ sl files -T '{path|slashpath}\n'
  ../b
  ../dir.h/foo
  ../t.h
  ../t/e.h
  ../t/x

  $ cd ../..
