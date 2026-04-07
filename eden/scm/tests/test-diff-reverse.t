
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ sl init repo
  $ cd repo

  $ cat > a << 'EOF'
  > a
  > b
  > c
  > EOF
  $ sl ci -Am adda
  adding a

  $ cat > a << 'EOF'
  > d
  > e
  > f
  > EOF
  $ sl ci -m moda

  $ sl diff --reverse -r0 -r1
  diff -r 2855cdcfcbb7 -r 8e1805a3cf6e a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,3 +1,3 @@
  -d
  -e
  -f
  +a
  +b
  +c

  $ cat >> a << 'EOF'
  > g
  > h
  > EOF
  $ sl diff --reverse --nodates
  diff -r 2855cdcfcbb7 a
  --- a/a
  +++ b/a
  @@ -1,5 +1,3 @@
   d
   e
   f
  -g
  -h

# should show removed file 'a' as being added

  $ sl revert a
  $ sl rm a
  $ sl diff --reverse --nodates a
  diff -r 2855cdcfcbb7 a
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,3 @@
  +d
  +e
  +f

# should show added file 'b' as being removed

  $ echo b >> b
  $ sl add b
  $ sl diff --reverse --nodates b
  diff -r 2855cdcfcbb7 b
  --- a/b
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -b
