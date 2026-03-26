
#require no-eden

# coding=utf-8

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable rebase
  $ setconfig phases.publish=False

  $ sl init a
  $ cd a

  $ echo A > A
  $ sl add A
  $ sl ci -m A

  $ echo B > B
  $ sl add B
  $ sl ci -m B

  $ echo C >> A
  $ sl ci -m C

  $ sl up -q -C 'min(_all())'

  $ echo D >> A
  $ sl ci -m D

  $ echo E > E
  $ sl add E
  $ sl ci -m E

  $ sl up -q -C 'min(_all())'

  $ echo F >> A
  $ sl ci -m F

  $ cd ..

# Rebasing B onto E - check keep: and phases

  $ cp -R a a1
  $ cd a1

  $ tglogp
  @  3225f3ea730a draft 'F'
  │
  │ o  ae36e8e3dfd7 draft 'E'
  │ │
  │ o  46b37eabc604 draft 'D'
  ├─╯
  │ o  965c486023db draft 'C'
  │ │
  │ o  27547f69f254 draft 'B'
  ├─╯
  o  4a2df7238c3b draft 'A'
  $ sl rebase -s 'desc(B)' -d 'desc(E)' --keep
  rebasing 27547f69f254 "B"
  rebasing 965c486023db "C"
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

# Solve the conflict and go on:

  $ echo 'conflict solved' > A
  $ rm A.orig
  $ sl resolve -m A
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  already rebased 27547f69f254 "B" as 45396c49d53b
  rebasing 965c486023db "C"

  $ tglogp
  o  d2d25e26288e draft 'C'
  │
  o  45396c49d53b draft 'B'
  │
  │ @  3225f3ea730a draft 'F'
  │ │
  o │  ae36e8e3dfd7 draft 'E'
  │ │
  o │  46b37eabc604 draft 'D'
  ├─╯
  │ o  965c486023db draft 'C'
  │ │
  │ o  27547f69f254 draft 'B'
  ├─╯
  o  4a2df7238c3b draft 'A'
  $ cd ..

# Rebase F onto E:

  $ cp -R a a2
  $ cd a2

  $ tglogp
  @  3225f3ea730a draft 'F'
  │
  │ o  ae36e8e3dfd7 draft 'E'
  │ │
  │ o  46b37eabc604 draft 'D'
  ├─╯
  │ o  965c486023db draft 'C'
  │ │
  │ o  27547f69f254 draft 'B'
  ├─╯
  o  4a2df7238c3b draft 'A'
  $ sl rebase -s 'desc(F)' -d 'desc(E)'
  rebasing 3225f3ea730a "F"
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

# Solve the conflict and go on:

  $ echo 'conflict solved' > A
  $ rm A.orig
  $ sl resolve -m A
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  rebasing 3225f3ea730a "F"

  $ tglogp
  @  530bc6058bd0 draft 'F'
  │
  o  ae36e8e3dfd7 draft 'E'
  │
  o  46b37eabc604 draft 'D'
  │
  │ o  965c486023db draft 'C'
  │ │
  │ o  27547f69f254 draft 'B'
  ├─╯
  o  4a2df7238c3b draft 'A'

  $ cd ..
