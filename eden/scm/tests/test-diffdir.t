
# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ newclientrepo repo
  $ touch a
  $ sl add a
  $ sl ci -m a

  $ echo 123 > b
  $ sl add b
  $ sl diff --nodates
  diff -r 3903775176ed b
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,1 @@
  +123

  $ sl diff --nodates -r tip
  diff -r 3903775176ed b
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,1 @@
  +123

  $ echo foo > a
  $ sl diff --nodates
  diff -r 3903775176ed a
  --- a/a
  +++ b/a
  @@ -0,0 +1,1 @@
  +foo
  diff -r 3903775176ed b
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,1 @@
  +123

  $ sl diff -r ''
  sl: parse error: empty query
  [255]
  $ sl diff -r tip -r ''
  sl: parse error: empty query
  [255]

# Remove a file that was added via merge. Since the file is not in parent 1,
# it should not be in the diff.

  $ sl ci -m 'a=foo' a
  $ sl co -Cq null
  $ echo 123 > b
  $ sl add b
  $ sl ci -m b
  $ sl merge 'desc("a=foo")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl rm -f a
  $ sl diff --nodates

# Rename a file that was added via merge. Since the rename source is not in
# parent 1, the diff should be relative to /dev/null

  $ sl co -Cq 'desc(b)'
  $ sl merge 'desc("a=foo")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl mv a a2
  $ sl diff --nodates
  diff -r cf44b38435e5 a2
  --- /dev/null
  +++ b/a2
  @@ -0,0 +1,1 @@
  +foo
  $ sl diff --nodates --git
  diff --git a/a2 b/a2
  new file mode 100644
  --- /dev/null
  +++ b/a2
  @@ -0,0 +1,1 @@
  +foo
