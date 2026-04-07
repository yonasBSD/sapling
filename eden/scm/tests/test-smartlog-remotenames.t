
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.


  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > smartlog=
  > [commitcloud]
  > enablestatus=false
  > EOF

  $ newclientrepo repo

  $ echo x > x
  $ sl commit -qAm x1
  $ sl book master1
  $ echo x >> x
  $ sl commit -qAm x2
  $ sl push -r . -q --to master1 --create

# Non-bookmarked public heads should not be visible in smartlog

  $ newclientrepo client repo_server master1
  $ sl book mybook -r 'desc(x1)'
  $ sl up 'desc(x1)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  o  x2  remote/master1
  │
  @  x1 mybook

# Old head (rev 1) is still visible

  $ echo z >> x
  $ sl commit -qAm x3
  $ sl push --non-forward-move -q --to master1
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  @  x3  remote/master1
  │
  o  x1 mybook

# Test configuration of "interesting" bookmarks

  $ sl up -q '.^'
  $ echo x >> x
  $ sl commit -qAm x4
  $ sl push -q --to project/bookmark --create
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  o  x3  remote/master1
  │
  │ @  x4
  ├─╯
  o  x1 mybook

  $ sl up '.^'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  o  x3  remote/master1
  │
  │ o  x4
  ├─╯
  @  x1 mybook
  $ cat >> $HGRCPATH << 'EOF'
  > [smartlog]
  > repos=remote/
  > names=project/bookmark
  > EOF
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  o  x3  remote/master1
  │
  │ o  x4
  ├─╯
  @  x1 mybook
  $ cat >> $HGRCPATH << 'EOF'
  > [smartlog]
  > names=master project/bookmark
  > EOF
  $ sl smartlog -T '{desc} {bookmarks} {remotebookmarks}'
  o  x3  remote/master1
  │
  │ o  x4
  ├─╯
  @  x1 mybook
