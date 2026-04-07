
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Set up without remotenames

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > rebase=
  > tweakdefaults=
  > EOF

  $ newclientrepo repo
  $ cd ..
  $ echo a > repo/a
  $ sl -R repo commit -qAm a
  $ sl -R repo bookmark master
  $ sl -R repo push -q -r . --to book --create
  $ newclientrepo clone repo_server book

# Pull --rebase with no local changes

  $ echo b > ../repo/b
  $ sl -R ../repo commit -qAm b
  $ sl -R ../repo push -q -r . --to book
  $ sl pull --rebase -d book
  pulling from test:repo_server
  searching for changes
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  nothing to rebase - fast-forwarded to book
  $ sl log -G -T '{desc} {desc}'
  @  b b
  │
  o  a a

# Make a local commit and check pull --rebase still works.

  $ echo x > x
  $ sl commit -qAm x
  $ echo c > ../repo/c
  $ sl -R ../repo commit -qAm c
  $ sl -R ../repo push -q -r . --to book
  $ sl pull --rebase -d book
  pulling from test:repo_server
  searching for changes
  rebasing 86d71924e1d0 "x"
  $ sl log -G -T '{desc} {desc}'
  @  x x
  │
  o  c c
  │
  o  b b
  │
  o  a a
