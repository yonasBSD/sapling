
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > reset=
  > [experimental]
  > evolution=
  > EOF

  $ sl init repo
  $ cd repo

  $ echo x > x
  $ sl commit -qAm x
  $ sl book foo

# Soft reset should leave pending changes

  $ echo y >> x
  $ sl commit -qAm y
  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  66ee28d0328c foo
  │
  o  b292c1e3311f
  $ sl reset '.^'
  1 changeset hidden
  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  b292c1e3311f foo
  $ sl diff
  diff -r b292c1e3311f x
  --- a/x	Thu Jan 01 00:00:00 1970 +0000
  +++ b/x	* (glob)
  @@ -1,1 +1,2 @@
   x
  +y

# Clean reset should overwrite all changes

  $ sl commit -qAm y

  $ sl reset --clean '.^'
  1 changeset hidden
  $ sl diff

# Reset should recover from backup bundles (with correct phase)

  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  b292c1e3311f foo
  $ sl debugmakepublic b292c1e3311f
  $ sl reset --clean 66ee28d0328c
  $ sl log -G -T '{node|short} {bookmarks} {phase}\n'
  @  66ee28d0328c foo draft
  │
  o  b292c1e3311f  public

# Reset should not strip reachable commits

  $ sl book bar
  $ sl reset --clean '.^'
  $ sl log -G -T '{node|short} {bookmarks}\n'
  o  66ee28d0328c foo
  │
  @  b292c1e3311f bar

  $ sl book -d bar
  $ sl up foo
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark foo)

# Reset to '.' by default

  $ echo z >> x
  $ echo z >> y
  $ sl add y
  $ sl st
  M x
  A y
  $ sl reset
  $ sl st
  M x
  ? y
  $ sl reset -C
  $ sl st
  ? y
  $ rm y

# Keep old commits

  $ sl reset --keep '.^'
  $ sl log -G -T '{node|short} {bookmarks}\n'
  o  66ee28d0328c
  │
  @  b292c1e3311f foo

# Reset without a bookmark

  $ sl up -C tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark foo)
  $ sl book -d foo
  $ sl reset '.^'
  1 changeset hidden
  $ sl book foo

# Reset to bookmark with - in the name

  $ sl reset 66ee28d0328c
  $ sl book foo-bar -r '.^'
  $ sl reset foo-bar
  1 changeset hidden
  $ sl book -d foo-bar

# Verify file status after reset

  $ sl reset -C 66ee28d0328c
  $ touch toberemoved
  $ sl commit -qAm 'add file for removal'
  $ echo z >> x
  $ touch tobeadded
  $ sl add tobeadded
  $ sl rm toberemoved
  $ sl commit -m 'to be reset'
  $ sl reset '.^'
  1 changeset hidden
  $ sl status
  M x
  ! toberemoved
  ? tobeadded
  $ sl reset -C 66ee28d0328c
  1 changeset hidden

# Reset + Obsolete tests

  $ cat >> .sl/config << 'EOF'
  > [extensions]
  > amend=
  > rebase=
  > [experimental]
  > evolution=all
  > EOF
  $ touch a
  $ sl commit -Aqm a
  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  7f3a02b3e388 foo
  │
  o  66ee28d0328c
  │
  o  b292c1e3311f

# Reset prunes commits

  $ sl reset -C '66ee28d0328c^'
  2 changesets hidden
  $ sl log -r 66ee28d0328c
  commit:      66ee28d0328c
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  b292c1e3311f foo
  $ sl reset -C 7f3a02b3e388
  $ sl log -G -T '{node|short} {bookmarks}\n'
  @  7f3a02b3e388 foo
  │
  o  66ee28d0328c
  │
  o  b292c1e3311f

# Reset to the commit your on is a no-op

  $ sl status
  $ sl log -r . -T '{node|short}\n'
  7f3a02b3e388
  $ sl reset .
  $ sl log -r . -T '{node|short}\n'
  7f3a02b3e388
  $ sl debugdirstate
  n 644          0 * a (glob)
  n 644          0 * tobeadded (glob)
  n 644          4 * x (glob)
