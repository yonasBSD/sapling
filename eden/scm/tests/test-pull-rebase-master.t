
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Test that `sl pull --rebase` works when the default branch is "master"
# and selectivepulldefault lists "main" first.
# Regression test for https://github.com/facebook/sapling/issues/1116

  $ export HGIDENTITY=sl
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > rebase=
  > tweakdefaults=
  > EOF

# Set up server repo with "master" as the only bookmark (no "main").
# Configure selectivepulldefault=main,master to simulate git-mode default.

  $ newclientrepo repo
  $ cd ..
  $ echo a > repo/a
  $ sl -R repo commit -qAm a
  $ sl -R repo push -q -r . --to master --create

# Clone with selectivepulldefault=main,master (main listed first, but only master exists)

  $ newclientrepo clone repo_server master
  $ setconfig remotenames.selectivepulldefault=main,master

# Pull --rebase with no local changes should auto-detect "master" as destination

  $ echo b > ../repo/b
  $ sl -R ../repo commit -qAm b
  $ sl -R ../repo push -q -r . --to master
  $ sl pull --rebase
  pulling from test:repo_server
  searching for changes
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  nothing to rebase - fast-forwarded to master

# Make a local commit and check pull --rebase still works without -d

  $ echo x > x
  $ sl commit -qAm x
  $ echo c > ../repo/c
  $ sl -R ../repo commit -qAm c
  $ sl -R ../repo push -q -r . --to master
  $ sl pull --rebase
  pulling from test:repo_server
  searching for changes
  rebasing * "x" (glob)
  $ sl log -G -T '{desc}'
  @  x
  │
  o  c
  │
  o  b
  │
  o  a
