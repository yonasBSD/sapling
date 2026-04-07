
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ setmodernconfig

  $ sl init repo
  $ cd repo
  $ echo xxx > file
  $ echo yyy > Æ
  $ sl add file
  $ sl add Æ
  $ sl commit -m 'Æ'

  $ sl log -v
  commit:      * (glob)
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       file Æ
  description:
  Æ

