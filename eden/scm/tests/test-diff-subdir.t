
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ sl init

  $ mkdir alpha
  $ touch alpha/one
  $ mkdir beta
  $ touch beta/two

  $ sl add alpha/one beta/two
  $ sl ci -m start

  $ echo 1 > alpha/one
  $ echo 2 > beta/two

# everything

  $ sl diff --nodates
  diff -r * alpha/one (glob)
  --- a/alpha/one
  +++ b/alpha/one
  @@ -0,0 +1,1 @@
  +1
  diff -r * beta/two (glob)
  --- a/beta/two
  +++ b/beta/two
  @@ -0,0 +1,1 @@
  +2

# beta only

  $ sl diff --nodates beta
  diff -r * beta/two (glob)
  --- a/beta/two
  +++ b/beta/two
  @@ -0,0 +1,1 @@
  +2

# inside beta

  $ cd beta
  $ sl diff --nodates .
  diff -r * beta/two (glob)
  --- a/beta/two
  +++ b/beta/two
  @@ -0,0 +1,1 @@
  +2

# relative to beta

  $ cd ..
  $ sl diff --nodates --root beta
  diff -r * two (glob)
  --- a/two
  +++ b/two
  @@ -0,0 +1,1 @@
  +2

# inside beta

  $ cd beta
  $ sl diff --nodates --root .
  diff -r * two (glob)
  --- a/two
  +++ b/two
  @@ -0,0 +1,1 @@
  +2

  $ cd ..
