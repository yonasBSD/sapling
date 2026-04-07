
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > reset=
  > EOF

  $ newclientrepo repo

  $ echo x > x
  $ sl commit -qAm x
  $ sl book foo
  $ echo x >> x
  $ sl commit -qAm x2
  $ sl push -q -r . --to foo --create

# Resetting past a remote bookmark should not delete the remote bookmark

  $ newclientrepo client repo_server foo
  $ sl book --list-remote *
  $ sl book bar
  $ sl reset --clean 'remote/foo^'
  $ sl log -G -T '{node|short} {bookmarks} {remotebookmarks}\n'
  o  a89d614e2364  remote/foo
  │
  @  b292c1e3311f bar
