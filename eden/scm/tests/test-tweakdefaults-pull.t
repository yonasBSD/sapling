#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable tweakdefaults
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ setconfig commands.update.check=noconflict
  $ setconfig tweakdefaults.defaultdest=remote/main

setup server and client

  $ sl init a
  $ cd a
  $ echo a > a
  $ sl ci -Aqm a
  $ sl book main
  $ newclientrepo b a
  $ sl pull -u -B main
  pulling from test:a
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

test a local modification

  $ echo aa > a
  $ sl pull -u -B main
  pulling from test:a
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl st
  M a
