
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Test whereami

  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo1
  $ cd repo1

  $ sl whereami
  0000000000000000000000000000000000000000

  $ echo a > a
  $ sl add a
  $ sl commit -m a

  $ sl whereami
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b

  $ echo b > b
  $ sl add b
  $ sl commit -m b

  $ sl up '.^'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ echo c > c
  $ sl add c
  $ sl commit -m c

  $ sl merge 'desc(b)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl whereami
  d36c0562f908c692f5204d606d4ff3537d41f1bf
  d2ae7f538514cd87c17547b0de4cea71fe1af9fb
