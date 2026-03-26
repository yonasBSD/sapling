
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ newrepo
  $ enable smartlog
  $ drawdag << 'EOS'
  > B C  # B has date 100000 0
  > |/   # C has date 200000 0
  > A
  > EOS
  $ sl bookmark -ir "$A" master
  $ sl log -r 'smartlog()' -T '{desc}\n'
  A
  B
  C
  $ sl log -r "smartlog($B)" -T '{desc}\n'
  A
  B
  $ sl log -r "smartlog(heads=$C, master=$B)" -T '{desc}\n'
  A
  B
  C
  $ sl log -r "smartlog(master=($A::)-$B-$C)" -T '{desc}\n'
  A
  B
  C
