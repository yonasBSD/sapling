
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > absorb=
  > EOF

  $ sl init repo
  $ cd repo
  $ sl debugdrawdag << 'EOS'
  > C
  > |
  > B
  > |
  > A
  > EOS

  $ sl debugmakepublic -r A

  $ sl goto C -q
  $ printf B1 > B

  $ sl absorb -aq

  $ sl log -G -T '{desc} {phase}'
  @  C draft
  │
  o  B draft
  │
  o  A public
