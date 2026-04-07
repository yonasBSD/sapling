
#require no-eden

# coding=utf-8

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ setconfig devel.segmented-changelog-rev-compat=true

  $ cat >> $HGRCPATH << 'EOF'
  > [extdiff]
  > # for portability:
  > pdiff = sh "$RUNTESTDIR/pdiff"
  > EOF

# enable morestatus outputs
  $ enable morestatus
  $ setconfig morestatus.show=true

# Create a repo with some stuff in it:

  $ newclientrepo
  $ echo a > a
  $ echo a > d
  $ echo a > e
  $ sl ci -qAm0
  $ echo b > a
  $ sl ci -m1 -u bar
  $ sl mv a b
  $ sl ci -m2
  $ sl cp b c
  $ sl ci -m3 -u baz
  $ echo b > d
  $ echo f > e
  $ sl ci -m4
  $ sl up -q 3
  $ echo b > e
  $ sl ci -m5

#  (Make sure mtime < fsnow to make the next merge commit stable)

  $ sleep 1

  $ sl status
  $ sl debugsetparents 4 5
  $ sl ci -m6

#  (Force "refersh" treestate)

  $ sl up -qC null
  $ sl up -qC tip
  $ sl debugmakepublic 3

  $ sl log -G --template '{author}@{rev}.{phase}: {desc}\n'
  @    test@6.draft: 6
  ├─╮
  │ o  test@5.draft: 5
  │ │
  o │  test@4.draft: 4
  ├─╯
  o  baz@3.public: 3
  │
  o  test@2.public: 2
  │
  o  bar@1.public: 1
  │
  o  test@0.public: 0

# Can't continue without starting:

  $ sl rm -q e
  $ sl graft --continue
  abort: no graft in progress
  [255]
  $ sl graft --abort
  abort: no graft in progress
  [255]
  $ sl revert -r . -q e

# Need to specify a rev:

  $ sl graft
  abort: no revisions specified
  [255]

# Empty revision set was specified

  $ sl graft -r '2::1'
  abort: empty revision set was specified
  [255]

# Can't graft ancestor:

  $ sl graft 1 2
  skipping ancestor revision 5d205f8b35b6
  skipping ancestor revision 5c095ad7e90f
  [255]

# Specify revisions with -r:

  $ sl graft -r 1 -r 2
  skipping ancestor revision 5d205f8b35b6
  skipping ancestor revision 5c095ad7e90f
  [255]

  $ sl graft -r 1 2
  warning: inconsistent use of --rev might give unexpected revision ordering!
  skipping ancestor revision 5c095ad7e90f
  skipping ancestor revision 5d205f8b35b6
  [255]

# Can't graft with dirty wd:

  $ sl up -q 0
  $ echo foo > a
  $ sl graft 1
  abort: uncommitted changes
  [255]
  $ sl revert a

# Graft a rename:
# (this also tests that editor is invoked if '--edit' is specified)

  $ sl status --rev '2^1' --rev 2
  A b
  R a
  $ HGEDITOR=cat sl graft 2 -u foo --edit
  grafting 5c095ad7e90f "2"
  merging a and b to b
  2
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: foo
  SL: added b
  SL: removed a
  $ sl export tip --git
  # SL changeset patch
  # User foo
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID ef0ef43d49e79e81ddafdc7997401ba0041efc82
  # Parent  68795b066622ca79a25816a662041d8f78f3cd9e
  2
  
  diff --git a/a b/b
  rename from a
  rename to b

# Look for extra:source

  $ sl log --debug -r tip
  commit:      ef0ef43d49e79e81ddafdc7997401ba0041efc82
  phase:       draft
  manifest:    e59b6b228f9cbf9903d5e9abf996e083a1f533eb
  user:        foo
  date:        Thu Jan 01 00:00:00 1970 +0000
  files+:      b
  files-:      a
  extra:       branch=default
  extra:       source=5c095ad7e90f871700f02dd1fa5012cb4498a2d4
  description:
  2

# Graft out of order, skipping a merge
# (this also tests that editor is not invoked if '--edit' is not specified)

  $ sl graft 1 5 4 3 'merge()' -n
  skipping ungraftable merge revision 6
  grafting 5d205f8b35b6 "1"
  grafting 5345cd5c0f38 "5"
  grafting 9c233e8e184d "4"
  grafting 4c60f11aa304 "3"

  $ HGEDITOR=cat sl graft 1 5 'merge()' --debug --config worker.backgroundclose=False
  skipping ungraftable merge revision 6
  grafting 5d205f8b35b6 "1"
  resolving manifests
   branchmerge: True, force: True
   ancestor: 68795b066622, local: ef0ef43d49e7+, remote: 5d205f8b35b6
   preserving b for resolve of b
   b: local copied/moved from a -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=b binary=False symlink=False changedelete=False
  merging b and a to b
  my b@ef0ef43d49e7+ other a@5d205f8b35b6 ancestor a@68795b066622
  committing files:
  b
  committing manifest
  committing changelog
  grafting 5345cd5c0f38 "5"
  resolving manifests
   branchmerge: True, force: True
   ancestor: 4c60f11aa304, local: 6b9e5368ca4e+, remote: 5345cd5c0f38
  committing files:
  e
  reusing remotefilelog node bc7ebe2d260cff30d2a39a130d84add36216f791
  committing manifest
  committing changelog
  $ HGEDITOR=cat sl graft 4 3 --log --debug
  grafting 9c233e8e184d "4"
  resolving manifests
   branchmerge: True, force: True
   ancestor: 4c60f11aa304, local: 9436191a062e+, remote: 9c233e8e184d
   preserving e for resolve of e
   e: versions differ -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=e binary=False symlink=False changedelete=False
  merging e
  my e@9436191a062e+ other e@9c233e8e184d ancestor e@4c60f11aa304
  warning: 1 conflicts while merging e! (edit, then use 'sl resolve --mark')
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue --log')
  [255]

# Summary should mention graft:

  $ sl summary
  parent: 9436191a062e 
   5
  commit: 2 modified, 2 unknown, 1 unresolved (graft in progress)
  phases: 6 draft

# Using status to get more context

  $ sl status
  M d
  M e
  ? a.orig
  ? e.orig
  
  # The repository is in an unfinished *graft* state.
  # Unresolved merge conflicts (1):
  # 
  #     e
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl graft --continue
  # To abort:                   sl graft --abort

# Commit while interrupted should fail:

  $ sl ci -m 'commit interrupted graft'
  abort: graft in progress
  (use 'sl graft --continue' to continue or
       'sl graft --abort' to abort)
  [255]

# Abort the graft and try committing:

  $ sl graft --abort
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl status --verbose
  ? a.orig
  ? e.orig
  $ echo c >> e
  $ sl ci -mtest

  $ sl debugstrip .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

# Graft again:

  $ sl graft 4 3 'merge()'
  skipping ungraftable merge revision 6
  grafting 9c233e8e184d "4"
  merging e
  warning: 1 conflicts while merging e! (edit, then use 'sl resolve --mark')
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]

# Continue without resolve should fail:

  $ sl continue
  grafting 9c233e8e184d "4"
  abort: unresolved merge conflicts (see 'sl help resolve')
  [255]

# Fix up:

  $ echo b > e
  $ sl resolve -m e
  (no more unresolved files)
  continue: sl graft --continue

# Continue with a revision should fail:

  $ sl graft -c 6
  abort: can't specify --continue and revisions
  [255]

  $ sl graft -c -r 6
  abort: can't specify --continue and revisions
  [255]

  $ sl graft --abort -r 6
  abort: can't specify --abort and revisions
  [255]

# Continue for real, clobber usernames

  $ sl graft -c -U
  grafting 9c233e8e184d "4"
  grafting 4c60f11aa304 "3"

# Compare with original:

  $ sl diff -r 6
  diff -r 7f1f8cbe8466 e
  --- a/e	Thu Jan 01 00:00:00 1970 +0000
  +++ b/e	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,1 @@
  -f
  +b

# XXX: Copy-tracing (b and c are "copied" from a) is somehow broken with the
# Rust debugstrip and invalidatelinkrev repo requirement. We probalby
# want to fix copy tracing or linkrev in other ways.

  $ sl status --rev '0:.' -C
  M d
  M e
  A b
    a
  A c
    a
  R a

# View graph:

  $ sl log -G --template '{author}@{rev}.{phase}: {desc}\n'
  @  test@11.draft: 3
  │
  o  test@10.draft: 4
  │
  o  test@9.draft: 5
  │
  o  bar@8.draft: 1
  │
  o  foo@7.draft: 2
  │
  │ o    test@6.draft: 6
  │ ├─╮
  │ │ o  test@5.draft: 5
  │ │ │
  │ o │  test@4.draft: 4
  │ ├─╯
  │ o  baz@3.public: 3
  │ │
  │ o  test@2.public: 2
  │ │
  │ o  bar@1.public: 1
  ├─╯
  o  test@0.public: 0

# Graft again onto another branch should preserve the original source

  $ sl up -q 0
  $ echo g > g
  $ sl add g
  $ sl ci -m 7
  $ sl graft 7
  grafting ef0ef43d49e7 "2"

  $ sl log -r 7 --template '{rev}:{node}\n'
  7:ef0ef43d49e79e81ddafdc7997401ba0041efc82
  $ sl log -r 2 --template '{rev}:{node}\n'
  2:5c095ad7e90f871700f02dd1fa5012cb4498a2d4

  $ sl log --debug -r tip
  commit:      7a4785234d87ec1aa420ed6b11afe40fa73e12a9
  phase:       draft
  manifest:    dc313617b8c32457c0d589e0dbbedfe71f3cd637
  user:        foo
  date:        Thu Jan 01 00:00:00 1970 +0000
  files+:      b
  files-:      a
  extra:       branch=default
  extra:       intermediate-source=ef0ef43d49e79e81ddafdc7997401ba0041efc82
  extra:       source=5c095ad7e90f871700f02dd1fa5012cb4498a2d4
  description:
  2
  $ sl up -q 6

  $ sl diff -r 2 -r 13
  diff -r 5c095ad7e90f -r 7a4785234d87 b
  --- a/b	Thu Jan 01 00:00:00 1970 +0000
  +++ b/b	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,1 @@
  -b
  +a
  diff -r 5c095ad7e90f -r 7a4785234d87 g
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/g	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +g

  $ sl diff -r 2 -r 13 -X .

# Graft with --log

  $ sl up -Cq 1
  $ sl graft 3 --log -u foo
  grafting 4c60f11aa304 "3"
  warning: can't find ancestor for 'c' copied from 'b'!
  $ sl log --template '{rev}:{node|short} {parents} {desc}\n' -r tip
  14:2618d22676d7 5d205f8b35b6  3
  
  (grafted from 4c60f11aa304a54ae1c199feb94e7fc771e51ed8)

# Resolve conflicted graft

  $ sl up -q 0
  $ echo b > a
  $ sl ci -m 8
  $ echo c > a
  $ sl ci -m 9
  $ sl graft 1 --tool 'internal:fail'
  grafting 5d205f8b35b6 "1"
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]
  $ sl resolve --all
  merging a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  [1]
  $ cat a
  <<<<<<< local: aaa4406d4f0a - test: 9
  c
  =======
  b
  >>>>>>> graft: 5d205f8b35b6 - bar: 1
  $ echo b > a
  $ sl resolve -m a
  (no more unresolved files)
  continue: sl graft --continue
  $ sl graft -c
  grafting 5d205f8b35b6 "1"
  $ sl export tip --git
  # SL changeset patch
  # User bar
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID f67661df0c4804d301f064f332b57e7d5ddaf2be
  # Parent  aaa4406d4f0ae9befd6e58c82ec63706460cbca6
  1
  
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -c
  +b

# Resolve conflicted graft with rename

  $ echo c > a
  $ sl ci -m 10
  $ sl graft 2 --tool 'internal:fail'
  grafting 5c095ad7e90f "2"
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]

# XXX: This part is broken because copy-tracing is broken.

  $ sl resolve --all
  merging a and b to b
  (no more unresolved files)
  continue: sl graft --continue
  $ sl graft -c
  grafting 5c095ad7e90f "2"
  $ sl export tip --git
  # SL changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID 9627f653b421c61fc1ea4c4e366745070fa3d2bc
  # Parent  ee295f490a40b97f3d18dd4c4f1c8936c233b612
  2
  
  diff --git a/a b/b
  rename from a
  rename to b

# graft with --force (still doesn't graft merges)

  $ newrepo
  $ drawdag << 'EOS'
  > C D
  > |/|
  > A B
  > EOS
  $ sl goto -q $C
  $ sl graft $B
  grafting fc2b737bb2e5 "B"
  $ sl rm A B C
  $ sl commit -m remove-all
  $ sl graft $A $D
  skipping ungraftable merge revision 3
  skipping ancestor revision 426bada5c675
  [255]
  $ sl graft $B $A $D --force
  skipping ungraftable merge revision 3
  grafting fc2b737bb2e5 "B"
  grafting 426bada5c675 "A"

# graft --force after backout

  $ echo abc > A
  $ sl ci -m to-backout
  $ sl bookmark -i to-backout
  $ sl backout to-backout
  reverting A
  changeset 14707ec2ae63 backs out changeset b2fde3ce6adf
  $ sl graft to-backout
  skipping ancestor revision b2fde3ce6adf
  [255]
  $ sl graft to-backout --force
  grafting b2fde3ce6adf "to-backout" (to-backout)
  $ cat A
  abc

# graft --continue after --force

  $ echo def > A
  $ sl ci -m 31
  $ sl graft to-backout --force --tool 'internal:fail'
  grafting b2fde3ce6adf "to-backout" (to-backout)
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]
  $ echo abc > A
  $ sl resolve -qm A
  continue: sl graft --continue
  $ sl graft -c
  grafting b2fde3ce6adf "to-backout" (to-backout)
  $ cat A
  abc

# Empty graft

  $ newrepo
  $ drawdag << 'EOS'
  > A  B  # B/A=A
  > EOS
  $ sl up -qr $B
  $ sl graft $A
  grafting 426bada5c675 "A"
  note: graft of 426bada5c675 created no changes to commit

# Graft to duplicate a commit

  $ newrepo graftsibling
  $ touch a
  $ sl commit -qAm a
  $ touch b
  $ sl commit -qAm b
  $ sl log -G -T '{rev}\n'
  @  1
  │
  o  0
  $ sl up -q 0
  $ sl graft -r 1
  grafting 0e067c57feba "b"
  $ sl log -G -T '{rev}\n'
  @  2
  │
  │ o  1
  ├─╯
  o  0

# Graft to duplicate a commit twice

  $ sl up -q 0
  $ sl graft -r 2
  grafting 044ec77f6389 "b"
  $ sl log -G -T '{rev}\n'
  @  3
  │
  │ o  2
  ├─╯
  │ o  1
  ├─╯
  o  0

# Graft from behind a move or rename
# ==================================
# NOTE: This is affected by issue5343, and will need updating when it's fixed
# Possible cases during a regular graft (when ca is between cta and c2):
# name | c1<-cta | cta<->ca | ca->c2
# A.0  |         |          |
# A.1  |    X    |          |
# A.2  |         |     X    |
# A.3  |         |          |   X
# A.4  |    X    |     X    |
# A.5  |    X    |          |   X
# A.6  |         |     X    |   X
# A.7  |    X    |     X    |   X
# A.0 is trivial, and doesn't need copy tracking.
# For A.1, a forward rename is recorded in the c1 pass, to be followed later.
# In A.2, the rename is recorded in the c2 pass and followed backwards.
# A.3 is recorded in the c2 pass as a forward rename to be duplicated on target.
# In A.4, both passes of checkcopies record incomplete renames, which are
# then joined in mergecopies to record a rename to be followed.
# In A.5 and A.7, the c1 pass records an incomplete rename, while the c2 pass
# records an incomplete divergence. The incomplete rename is then joined to the
# appropriate side of the incomplete divergence, and the result is recorded as a
# divergence. The code doesn't distinguish at all between these two cases, since
# the end result of them is the same: an incomplete divergence joined with an
# incomplete rename into a divergence.
# Finally, A.6 records a divergence entirely in the c2 pass.
# A.4 has a degenerate case a<-b<-a->a, where checkcopies isn't needed at all.
# A.5 has a special case a<-b<-b->a, which is treated like a<-b->a in a merge.
# A.6 has a special case a<-a<-b->a. Here, checkcopies will find a spurious
# incomplete divergence, which is in fact complete. This is handled later in
# mergecopies.
# A.7 has 4 special cases: a<-b<-a->b (the "ping-pong" case), a<-b<-c->b,
# a<-b<-a->c and a<-b<-c->a. Of these, only the "ping-pong" case is interesting,
# the others are fairly trivial (a<-b<-c->b and a<-b<-a->c proceed like the base
# case, a<-b<-c->a is treated the same as a<-b<-b->a).
# f5a therefore tests the "ping-pong" rename case, where a file is renamed to the
# same name on both branches, then the rename is backed out on one branch, and
# the backout is grafted to the other branch. This creates a challenging rename
# sequence of a<-b<-a->b in the graft target, topological CA, graft CA and graft
# source, respectively. Since rename detection will run on the c1 side for such a
# sequence (as for technical reasons, we split the c1 and c2 sides not at the
# graft CA, but rather at the topological CA), it will pick up a false rename,
# and cause a spurious merge conflict. This false rename is always exactly the
# reverse of the true rename that would be detected on the c2 side, so we can
# correct for it by detecting this condition and reversing as necessary.
# First, set up the repository with commits to be grafted

  $ newclientrepo graftmove
  $ echo c1a > f1a
  $ echo c2a > f2a
  $ echo c3a > f3a
  $ echo c4a > f4a
  $ echo c5a > f5a
  $ sl ci -qAm A0
  $ sl mv f1a f1b
  $ sl mv f3a f3b
  $ sl mv f5a f5b
  $ sl ci -qAm B0
  $ echo c1c > f1b
  $ sl mv f2a f2c
  $ sl mv f5b f5a
  $ echo c5c > f5a
  $ sl ci -qAm C0
  $ sl mv f3b f3d
  $ echo c4d > f4a
  $ sl ci -qAm D0
  $ sl log -G
  @  commit:      b69f5839d2d9
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     D0
  │
  o  commit:      f58c7e2b28fa
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     C0
  │
  o  commit:      3d7bba921b5d
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     B0
  │
  o  commit:      11f7a1b56675
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     A0

# Test the cases A.2 (f1x), A.3 (f2x) and a special case of A.6 (f5x) where the
# two renames actually converge to the same name (thus no actual divergence).

  $ sl up -q 'desc("A0")'
  $ HGEDITOR='echo C1 >' sl graft -r 'desc("C0")' --edit
  grafting f58c7e2b28fa "C0"
  merging f1a and f1b to f1a
  merging f5a
  warning: can't find ancestor for 'f5a' copied from 'f5b'!
  $ sl status --change .
  M f1a
  M f5a
  A f2c
  R f2a
  $ sl cat f1a
  c1c
  $ sl cat f1b
  [1]

# Test the cases A.0 (f4x) and A.6 (f3x)

  $ HGEDITOR='echo D1 >' sl graft -r 'desc("D0")' --edit
  grafting b69f5839d2d9 "D0"
  warning: can't find ancestor for 'f3d' copied from 'f3b'!

# Set up the repository for some further tests

  $ sl up -q 'min(desc(A0))'
  $ sl mv f1a f1e
  $ echo c2e > f2a
  $ sl mv f3a f3e
  $ sl mv f4a f4e
  $ sl mv f5a f5b
  $ sl ci -qAm E0
  $ sl log -G
  @  commit:      6bd1736cab86
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     E0
  │
  │ o  commit:      560daee679da
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  summary:     D1
  │ │
  │ o  commit:      c9763722f9bd
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     C1
  │
  │ o  commit:      b69f5839d2d9
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  summary:     D0
  │ │
  │ o  commit:      f58c7e2b28fa
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  summary:     C0
  │ │
  │ o  commit:      3d7bba921b5d
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     B0
  │
  o  commit:      11f7a1b56675
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     A0

# Test the cases A.4 (f1x), the "ping-pong" special case of A.7 (f5x),
# and A.3 with a local content change to be preserved (f2x).

  $ HGEDITOR='echo C2 >' sl graft -r 'desc("C0")' --edit
  grafting f58c7e2b28fa "C0"
  merging f1e and f1b to f1e
  merging f2a and f2c to f2c

# Test the cases A.1 (f4x) and A.7 (f3x).

  $ HGEDITOR='echo D2 >' sl graft -r 'desc("D0")' --edit
  grafting b69f5839d2d9 "D0"
  merging f4e and f4a to f4e
  warning: can't find ancestor for 'f3d' copied from 'f3b'!

# Check the results of the grafts tested

  $ sl log -CGv --patch --git
  @  commit:      93ee502e8b0a
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  files:       f3d f4e
  │  description:
  │  D2
  │
  │
  │  diff --git a/f3d b/f3d
  │  new file mode 100644
  │  --- /dev/null
  │  +++ b/f3d
  │  @@ -0,0 +1,1 @@
  │  +c3a
  │  diff --git a/f4e b/f4e
  │  --- a/f4e
  │  +++ b/f4e
  │  @@ -1,1 +1,1 @@
  │  -c4a
  │  +c4d
  │
  o  commit:      539cf145f496
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  files:       f1e f2a f2c f5a f5b
  │  copies:      f2c (f2a) f5a (f5b)
  │  description:
  │  C2
  │
  │
  │  diff --git a/f1e b/f1e
  │  --- a/f1e
  │  +++ b/f1e
  │  @@ -1,1 +1,1 @@
  │  -c1a
  │  +c1c
  │  diff --git a/f2a b/f2c
  │  rename from f2a
  │  rename to f2c
  │  diff --git a/f5b b/f5a
  │  rename from f5b
  │  rename to f5a
  │  --- a/f5b
  │  +++ b/f5a
  │  @@ -1,1 +1,1 @@
  │  -c5a
  │  +c5c
  │
  o  commit:      6bd1736cab86
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  files:       f1a f1e f2a f3a f3e f4a f4e f5a f5b
  │  copies:      f1e (f1a) f3e (f3a) f4e (f4a) f5b (f5a)
  │  description:
  │  E0
  │
  │
  │  diff --git a/f1a b/f1e
  │  rename from f1a
  │  rename to f1e
  │  diff --git a/f2a b/f2a
  │  --- a/f2a
  │  +++ b/f2a
  │  @@ -1,1 +1,1 @@
  │  -c2a
  │  +c2e
  │  diff --git a/f3a b/f3e
  │  rename from f3a
  │  rename to f3e
  │  diff --git a/f4a b/f4e
  │  rename from f4a
  │  rename to f4e
  │  diff --git a/f5a b/f5b
  │  rename from f5a
  │  rename to f5b
  │
  │ o  commit:      560daee679da
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  files:       f3d f4a
  │ │  description:
  │ │  D1
  │ │
  │ │
  │ │  diff --git a/f3d b/f3d
  │ │  new file mode 100644
  │ │  --- /dev/null
  │ │  +++ b/f3d
  │ │  @@ -0,0 +1,1 @@
  │ │  +c3a
  │ │  diff --git a/f4a b/f4a
  │ │  --- a/f4a
  │ │  +++ b/f4a
  │ │  @@ -1,1 +1,1 @@
  │ │  -c4a
  │ │  +c4d
  │ │
  │ o  commit:      c9763722f9bd
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    files:       f1a f2a f2c f5a
  │    copies:      f2c (f2a)
  │    description:
  │    C1
  │
  │
  │    diff --git a/f1a b/f1a
  │    --- a/f1a
  │    +++ b/f1a
  │    @@ -1,1 +1,1 @@
  │    -c1a
  │    +c1c
  │    diff --git a/f2a b/f2c
  │    rename from f2a
  │    rename to f2c
  │    diff --git a/f5a b/f5a
  │    --- a/f5a
  │    +++ b/f5a
  │    @@ -1,1 +1,1 @@
  │    -c5a
  │    +c5c
  │
  │ o  commit:      b69f5839d2d9
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  files:       f3b f3d f4a
  │ │  copies:      f3d (f3b)
  │ │  description:
  │ │  D0
  │ │
  │ │
  │ │  diff --git a/f3b b/f3d
  │ │  rename from f3b
  │ │  rename to f3d
  │ │  diff --git a/f4a b/f4a
  │ │  --- a/f4a
  │ │  +++ b/f4a
  │ │  @@ -1,1 +1,1 @@
  │ │  -c4a
  │ │  +c4d
  │ │
  │ o  commit:      f58c7e2b28fa
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  files:       f1b f2a f2c f5a f5b
  │ │  copies:      f2c (f2a) f5a (f5b)
  │ │  description:
  │ │  C0
  │ │
  │ │
  │ │  diff --git a/f1b b/f1b
  │ │  --- a/f1b
  │ │  +++ b/f1b
  │ │  @@ -1,1 +1,1 @@
  │ │  -c1a
  │ │  +c1c
  │ │  diff --git a/f2a b/f2c
  │ │  rename from f2a
  │ │  rename to f2c
  │ │  diff --git a/f5b b/f5a
  │ │  rename from f5b
  │ │  rename to f5a
  │ │  --- a/f5b
  │ │  +++ b/f5a
  │ │  @@ -1,1 +1,1 @@
  │ │  -c5a
  │ │  +c5c
  │ │
  │ o  commit:      3d7bba921b5d
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    files:       f1a f1b f3a f3b f5a f5b
  │    copies:      f1b (f1a) f3b (f3a) f5b (f5a)
  │    description:
  │    B0
  │
  │
  │    diff --git a/f1a b/f1b
  │    rename from f1a
  │    rename to f1b
  │    diff --git a/f3a b/f3b
  │    rename from f3a
  │    rename to f3b
  │    diff --git a/f5a b/f5b
  │    rename from f5a
  │    rename to f5b
  │
  o  commit:      11f7a1b56675
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     files:       f1a f2a f3a f4a f5a
     description:
     A0
  
  
     diff --git a/f1a b/f1a
     new file mode 100644
     --- /dev/null
     +++ b/f1a
     @@ -0,0 +1,1 @@
     +c1a
     diff --git a/f2a b/f2a
     new file mode 100644
     --- /dev/null
     +++ b/f2a
     @@ -0,0 +1,1 @@
     +c2a
     diff --git a/f3a b/f3a
     new file mode 100644
     --- /dev/null
     +++ b/f3a
     @@ -0,0 +1,1 @@
     +c3a
     diff --git a/f4a b/f4a
     new file mode 100644
     --- /dev/null
     +++ b/f4a
     @@ -0,0 +1,1 @@
     +c4a
     diff --git a/f5a b/f5a
     new file mode 100644
     --- /dev/null
     +++ b/f5a
     @@ -0,0 +1,1 @@
     +c5a
  $ sl cat f2c
  c2e

# Check superfluous filemerge of files renamed in the past but untouched by graft

  $ echo a > a
  $ sl ci -qAma
  $ sl mv a b
  $ echo b > b
  $ sl ci -qAmb
  $ echo c > c
  $ sl ci -qAmc
  $ sl up -q '.~2'
  $ sl graft tip '-qt:fail'

  $ cd ..

# Graft a change into a new file previously grafted into a renamed directory
# todo: support directory move detection

  $ newclientrepo dirmovenewfile
  $ mkdir a
  $ echo a > a/a
  $ sl ci -qAma
  $ echo x > a/x
  $ sl ci -qAmx
  $ sl up -q 0
  $ sl mv -q a b
  $ sl ci -qAmb
  $ sl graft -q 1
  $ sl up -q 1
  $ echo y > a/x
  $ sl ci -qAmy
  $ sl up -q 3
  $ sl graft -q 4
  $ sl status --change .
  M a/x

# Prepare for test of skipped changesets and how merges can influence it:

  $ sl merge -q -r 1 --tool ':local'
  $ sl ci -m m
  $ echo xx >> a/x
  $ sl ci -m xx

  $ sl log -G -T '{rev} {desc|firstline}'
  @  7 xx
  │
  o    6 m
  ├─╮
  │ o  5 y
  │ │
  │ │ o  4 y
  ├───╯
  │ o  3 x
  │ │
  │ o  2 b
  │ │
  o │  1 x
  ├─╯
  o  0 a

# Grafting of plain changes correctly detects that 3 and 5 should be skipped:

  $ sl up -qCr 4
  $ sl graft --tool ':local' -r '2'
  grafting 7ea085edaaef "b"

# Extending the graft range to include a (skipped) merge of 3 will not prevent us from
# also detecting that both 3 and 5 should be skipped:

  $ sl up -qCr 4
  $ sl graft --tool ':local' -r '2 + 6 + 7'
  skipping ungraftable merge revision 6
  grafting 7ea085edaaef "b"
  grafting c9302879a6a3 "xx"

  $ cd ..


Can use --message-field to update parts of commit message.
  $ newclientrepo
  $ touch foo
  $ sl commit -Aqm "title
  > 
  > Summary:
  > summary
  > 
  > Test Plan:
  > test plan"
  $ sl whereami
  2d2e42cdf85511ef5011a5cf09d60e5c319d9e9b
  $ sl go -q null
  $ touch bar
  $ sl commit -Aqm bar
  $ sl graft -r 2d2e42cdf --message-field="Summary=
  > new summary
  > "
  grafting 2d2e42cdf855 "title"
  $ sl show
  commit:      c05be0f0fd33
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo
  description:
  title
  
  Summary:
  new summary
  
  Test Plan:
  test plan
  $ sl go -q .^
  $ sl graft -r 2d2e42cdf --log --message-field="Summary=
  > new summary
  > "
  grafting 2d2e42cdf855 "title"
  $ sl show
  commit:      46a7e5630e37
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo
  description:
  title
  
  Summary:
  new summary
  
  (grafted from 2d2e42cdf85511ef5011a5cf09d60e5c319d9e9b)
  
  Test Plan:
  test plan

# Test graft -m and -l options

  $ newclientrepo
  $ drawdag <<'EOS'
  > C   # C/foo/x = 1a\n2\n3a\n
  > |
  > B   # B/foo/x = 1a\n2\n3\n
  > |
  > A   # A/foo/x = 1\n2\n3\n
  >     # drawdag.defaultfiles=false
  > EOS
  $ sl go $A -q
  $ sl graft -r $C -m "new C"
  grafting 78072751cf70 "C"
  merging foo/x
  $ sl show
  commit:      a466a52d5162
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo/x
  description:
  new C
  
  
  diff -r 2f10237b4399 -r a466a52d5162 foo/x
  --- a/foo/x	Thu Jan 01 00:00:00 1970 +0000
  +++ b/foo/x	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,3 +1,3 @@
   1
   2
  -3
  +3a

  $ sl go $A -q
  $ echo "my commit message" > my_logfile.txt
  $ sl graft -r $C -l my_logfile.txt
  grafting 78072751cf70 "C"
  merging foo/x
  $ sl show
  commit:      daf80b302751
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo/x
  description:
  my commit message
  
  
  diff -r 2f10237b4399 -r daf80b302751 foo/x
  --- a/foo/x	Thu Jan 01 00:00:00 1970 +0000
  +++ b/foo/x	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,3 +1,3 @@
   1
   2
  -3
  +3a
