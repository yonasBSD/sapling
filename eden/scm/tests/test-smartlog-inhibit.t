
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > amend=
  > smartlog=
  > [experimental]
  > evolution = createmarkers
  > EOF

# Test that changesets with visible precursors are rendered as x's

  $ sl init repo
  $ cd repo
  $ sl debugbuilddag +4
  $ sl book -r 'desc(r3)' test
  $ sl up 'desc(r1)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl amend -m amended --no-rebase
  hint[amend-restack]: descendants of 66f7d451a68b are left behind - use 'sl restack' to rebase them
  hint[hint-ack]: use 'sl hint --ack amend-restack' to silence these hints
  $ sl smartlog -T '{desc|firstline} {bookmarks}'
  o  r3 test
  │
  o  r2
  │
  x  r1
  │
  │ @  amended
  ├─╯
  o  r0
  $ sl unamend
  $ sl up 'desc(r2)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl debugmakepublic -r .
  $ sl smartlog -T '{desc|firstline} {bookmarks}'
  o  r3 test
  │
  @  r2
  │
  ~
