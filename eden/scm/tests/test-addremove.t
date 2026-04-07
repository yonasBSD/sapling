
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ sl init rep
  $ cd rep
  $ mkdir dir
  $ touch foo dir/bar
  $ sl -v addremove
  adding dir/bar
  adding foo
  $ sl -v commit -m 'add 1'
  committing files:
  dir/bar
  foo
  committing manifest
  committing changelog
  committed * (glob)
  $ cd dir/
  $ touch ../foo_2 bar_2
  $ sl -v addremove
  adding dir/bar_2
  adding foo_2
  $ sl -v commit -m 'add 2'
  committing files:
  dir/bar_2
  foo_2
  committing manifest
  committing changelog
  committed * (glob)
  $ cd ..
  $ sl forget foo
  $ sl -v addremove
  adding foo
  $ sl forget foo

  $ sl -v addremove nonexistent
  nonexistent: $ENOENT$
  [1]

  $ cd ..

  $ sl init subdir
  $ cd subdir
  $ mkdir dir
  $ cd dir
  $ touch a.py
  $ sl addremove 'glob:*.py'
  adding a.py
  $ sl forget a.py
  $ sl addremove -I 'glob:*.py'
  adding a.py
  $ sl forget a.py
  $ sl addremove
  adding dir/a.py
  $ cd ..
  $ cd ..

  $ sl init sim
  $ cd sim
  $ echo a > a
  $ echo a >> a
  $ echo a >> a
  $ echo c > c
  $ sl commit -Ama
  adding a
  adding c
  $ mv a b
  $ rm c
  $ echo d > d
  $ sl addremove -n -s 50
  removing a
  adding b
  removing c
  adding d
  recording removal of a as rename to b (100% similar)
  $ sl addremove -s 50
  removing a
  adding b
  removing c
  adding d
  recording removal of a as rename to b (100% similar)
  $ sl commit -mb
  $ cp b c
  $ sl forget b
  $ sl addremove -s 50
  adding b
  adding c

  $ rm c

  $ sl ci -A -m c nonexistent
  nonexistent: $ENOENT$
  abort: failed to mark all new/missing files as added/removed
  [255]

  $ sl st
  ! c

  $ sl forget c
  $ touch foo
  $ sl addremove
  adding foo
  $ rm foo
  $ sl addremove
  removing foo

  $ cd ..
