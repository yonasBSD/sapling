
#require no-eden

# coding=utf-8

# coding=utf-8

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# This test file aims at test topological iteration and the various configuration it can has.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [ui]
  > logtemplate={desc|firstline}\n
  > allowemptycommit=True
  > EOF

# On this simple example, all topological branch are displayed in turn until we
# can finally display 0. this implies skipping from 8 to 3 and coming back to 7
# later.

  $ sl init test01
  $ cd test01
  $ sl commit -qm 0
  $ sl commit -qm 1
  $ sl commit -qm 2
  $ sl commit -qm 3
  $ sl up -q 'desc(0)'
  $ sl commit -qm 4
  $ sl commit -qm 5
  $ sl commit -qm 6
  $ sl commit -qm 7
  $ sl up -q 'desc(3)'
  $ sl commit -qm 8
  $ sl up -q null

  $ sl log -G
  o  8
  │
  │ o  7
  │ │
  │ o  6
  │ │
  │ o  5
  │ │
  │ o  4
  │ │
  o │  3
  │ │
  o │  2
  │ │
  o │  1
  ├─╯
  o  0

# (display all nodes)

  $ sl log -G -r 'sort(all(), topo)'
  o  8
  │
  o  3
  │
  o  2
  │
  o  1
  │
  │ o  7
  │ │
  │ o  6
  │ │
  │ o  5
  │ │
  │ o  4
  ├─╯
  o  0

# (revset skipping nodes)

  $ sl log -G --rev 'sort(not (desc(2)+desc(6)), topo)'
  o  8
  │
  o  3
  ╷
  o  1
  │
  │ o  7
  │ ╷
  │ o  5
  │ │
  │ o  4
  ├─╯
  o  0

# (begin) from the other branch

  $ sl log -G -r 'sort(all(), topo, topo.firstbranch=desc(5))'
  o  7
  │
  o  6
  │
  o  5
  │
  o  4
  │
  │ o  8
  │ │
  │ o  3
  │ │
  │ o  2
  │ │
  │ o  1
  ├─╯
  o  0
