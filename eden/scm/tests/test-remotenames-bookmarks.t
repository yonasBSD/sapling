
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo

# Setup repo

  $ sl init repo
  $ cd repo
  $ echo foo > a.txt
  $ sl add a.txt
  $ sl commit -m a

# Testing bookmark options without args

  $ sl bookmark a
  $ sl bookmark b
  $ sl bookmark -v
     a                         2dcb9139ea49
   * b                         2dcb9139ea49
  $ sl bookmark --track a
  $ sl bookmark -v
     a                         2dcb9139ea49
   * b                         2dcb9139ea49[a]
  $ sl bookmark --untrack
  $ sl bookmark -v
     a                         2dcb9139ea49
   * b                         2dcb9139ea49
