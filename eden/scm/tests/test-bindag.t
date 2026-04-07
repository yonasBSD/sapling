
#require no-eden

# coding=utf-8

# coding=utf-8

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ newrepo
  $ sl debugdrawdag << 'EOS'
  > J K
  > |/|
  > H I
  > | |
  > F G
  > |/
  > E
  > |\
  > A D
  > |\|
  > B C
  > EOS

  $ sl debugbindag -r '::A' -o a.dag
  $ sl debugpreviewbindag a.dag
  o    2
  ├─╮
  o │  1
    │
    o  0

  $ sl debugbindag -r '::J' -o j.dag
  $ sl debugpreviewbindag j.dag
  o  7
  │
  o  6
  │
  o  5
  │
  o    4
  ├─╮
  │ o  3
  │ │
  o │  2
  ├─╮
  │ o  1
  │
  o  0

  $ sl debugbindag -r 'all()' -o all.dag
  $ sl debugpreviewbindag all.dag
  o    10
  ├─╮
  │ │ o  9
  │ ├─╯
  o │  8
  │ │
  │ o  7
  │ │
  o │  6
  │ │
  │ o  5
  ├─╯
  o    4
  ├─╮
  │ o  3
  │ │
  o │  2
  ├─╮
  │ o  1
  │
  o  0
