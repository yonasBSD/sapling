
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# https://bz.mercurial-scm.org/660 and:
# https://bz.mercurial-scm.org/322

  $ setconfig commands.update.check=none
  $ eagerepo

  $ sl init repo
  $ cd repo
  $ echo a > a
  $ mkdir b
  $ echo b > b/b
  $ sl commit -A -m 'a is file, b is dir'
  adding a
  adding b/b

# File replaced with directory:

  $ rm a
  $ mkdir a
  $ echo a > a/a

# Should fail - would corrupt dirstate:

  $ sl add a/a
  abort: file 'a' in dirstate clashes with 'a/a'
  [255]

# Removing shadow:

  $ sl rm --mark a

# Should succeed - shadow removed:

  $ sl add a/a

# Directory replaced with file:

  $ rm -r b
  $ echo b > b

# Should fail - would corrupt dirstate:

  $ sl add b
  abort: directory 'b' already in dirstate
  [255]

# Removing shadow:

  $ sl rm --mark b/b

# Should succeed - shadow removed:

  $ sl add b

# Look what we got:

  $ sl st
  A a/a
  A b
  R a
  R b/b

# Revert reintroducing shadow - should fail:

  $ rm -r a b
  $ sl revert b/b
  abort: file 'b' in dirstate clashes with 'b/b'
  [255]

# Revert all - should succeed:

  $ sl revert --all
  undeleting a
  forgetting a/a
  forgetting b
  undeleting b/b

  $ sl st

# Issue3423:

  $ sl forget a
  $ echo zed > a
  $ sl revert a
  $ sl st
  ? a.orig
  $ rm a.orig

# addremove:

  $ rm -r a b
  $ mkdir a
  $ echo a > a/a
  $ echo b > b

  $ sl addremove -s 0
  removing a
  adding a/a
  adding b
  removing b/b

  $ sl st
  A a/a
  A b
  R a
  R b/b

# commit:

  $ sl ci -A -m 'a is dir, b is file'
  $ sl st --all
  C a/a
  C b

# Long directory replaced with file:

  $ mkdir d
  $ mkdir d/d
  $ echo d > d/d/d
  $ sl commit -A -m 'd is long directory'
  adding d/d/d

  $ rm -r d
  $ echo d > d

# Should fail - would corrupt dirstate:

  $ sl add d
  abort: directory 'd' already in dirstate
  [255]

# Removing shadow:

  $ sl rm --mark d/d/d

# Should succeed - shadow removed:

  $ sl add d
  $ sl ci -md

# Update should work at least with clean working directory:

  $ rm -r a b d
  $ sl up -r 'desc("a is file, b is dir")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl st --all
  C a
  C b/b

  $ rm -r a b
  $ sl up -r 'desc("a is dir, b is file")'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl st --all
  C a/a
  C b
