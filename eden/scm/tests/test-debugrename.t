
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo a > a
  $ sl ci -Am t
  adding a

  $ sl mv a b
  $ sl ci -Am t1
  $ sl debugrename b
  b renamed from a:b789fdd96dc2f3bd229c1dd8eedf0fc60e2b68e3

  $ sl mv b a
  $ sl ci -Am t2
  $ sl debugrename a
  a renamed from b:37d9b5d994eab34eda9c16b195ace52c7b129980

  $ sl debugrename --rev 'desc(t1)' b
  b renamed from a:b789fdd96dc2f3bd229c1dd8eedf0fc60e2b68e3
