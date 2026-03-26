
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ eagerepo

  $ sl init a
  $ cd a
  $ sl init b
  $ sl st

Fsmonitor doesn't handle nested repos well, but the above test shows we at least don't
consider files under the nested ".sl" directory.
#if no-fsmonitor

  $ echo a > a
  $ sl ci -Ama a
  $ echo x > b/x

# Should print nothing:

  $ sl add b
  $ sl st

  $ echo y > b/y
  $ sl st

# These should ideally fail, although not failing is not causing security issues:

  $ sl add b/x
  $ sl add b b/x
  $ sl mv a b

  $ cd ..

#endif
