
#require no-eden

# coding=utf-8
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > amend=
  > undo =
  > [experimental]
  > evolution = obsolete
  > [mutation]
  > enabled = true
  > [visibility]
  > enabled = true
  > EOF

# Create repo

  $ sl init repo
  $ cd repo
  $ drawdag << 'EOS'
  > E
  > |
  > C D
  > |/
  > B
  > |
  > A
  > EOS

  $ sl book -r $C cat
  $ sl book -r $B dog
  $ sl goto $A
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl log -G -T '{desc} {bookmarks}\n'
  o  E
  │
  │ o  D
  │ │
  o │  C cat
  ├─╯
  o  B dog
  │
  @  A

# Hide a single commit

  $ sl hide $D
  hiding commit be0ef73c17ad "D"
  1 changeset hidden
  hint[undo]: you can undo this using the `sl undo` command
  hint[hint-ack]: use 'sl hint --ack undo' to silence these hints
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  E
  │
  o  C cat
  │
  o  B dog
  │
  @  A

# Hide multiple commits with bookmarks on them, hide wc parent

  $ sl goto $B
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl hide .
  hiding commit 112478962961 "B"
  hiding commit 26805aba1e60 "C"
  hiding commit 78d2dca436b2 "E"
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  working directory now at 426bada5c675
  3 changesets hidden
  removing bookmark 'cat' (was at: 26805aba1e60)
  removing bookmark 'dog' (was at: 112478962961)
  2 bookmarks removed
  hint[undo]: you can undo this using the `sl undo` command
  hint[hint-ack]: use 'sl hint --ack undo' to silence these hints
  $ sl log -G -T '{desc} {bookmarks}\n'
  @  A

# Unhide stuff

  $ sl unhide 'desc(C)'
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  C
  │
  o  B
  │
  @  A
  $ sl unhide -r 'desc(E)' -r 'desc(D)'
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  E
  │
  │ o  D
  │ │
  o │  C
  ├─╯
  o  B
  │
  @  A

# hg hide --cleanup tests

  $ sl goto 'desc(E)'
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo f > f
  $ sl add f
  $ sl commit -d '0 0' -m F
  $ sl goto 'desc(E)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl amend --no-rebase -m E2 -d '0 0'
  hint[amend-restack]: descendants of 78d2dca436b2 are left behind - use 'sl restack' to rebase them
  hint[hint-ack]: use 'sl hint --ack amend-restack' to silence these hints
  $ sl log -G -T '{desc} {bookmarks}\n'
  @  E2
  │
  │ o  F
  │ │
  │ x  E
  ├─╯
  │ o  D
  │ │
  o │  C
  ├─╯
  o  B
  │
  o  A
  $ sl hide -c
  abort: nothing to hide
  [255]
  $ sl hide -c -r .
  abort: --rev and --cleanup are incompatible
  [255]
  $ sl --config 'extensions.rebase=' rebase -s 'desc(F)' -d 'desc(E2)'
  rebasing 1f7934a9b4de "F"
  $ sl book -r 1f7934a9b4de alive --hidden
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  F
  │
  @  E2
  │
  │ x  F alive
  │ │
  │ x  E
  ├─╯
  │ o  D
  │ │
  o │  C
  ├─╯
  o  B
  │
  o  A
  $ sl hide --cleanup
  hiding commit 78d2dca436b2 "E"
  hiding commit 1f7934a9b4de "F"
  2 changesets hidden
  removing bookmark 'alive' (was at: 1f7934a9b4de)
  1 bookmark removed
  hint[undo]: you can undo this using the `sl undo` command
  hint[hint-ack]: use 'sl hint --ack undo' to silence these hints
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  F
  │
  @  E2
  │
  │ o  D
  │ │
  o │  C
  ├─╯
  o  B
  │
  o  A

# Hiding the head bookmark of a stack hides the stack.

  $ sl book -r 'desc(D)' somebookmark
  $ sl hide -B somebookmark
  hiding commit be0ef73c17ad "D"
  1 changeset hidden
  removing bookmark 'somebookmark' (was at: be0ef73c17ad)
  1 bookmark removed
  hint[undo]: you can undo this using the `sl undo` command
  hint[hint-ack]: use 'sl hint --ack undo' to silence these hints
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  F
  │
  @  E2
  │
  o  C
  │
  o  B
  │
  o  A

# Hiding a bookmark in the middle of a stack just deletes the bookmark.

  $ sl book -r 'desc(C)' stackmidbookmark
  $ sl hide -B stackmidbookmark
  removing bookmark 'stackmidbookmark' (was at: 26805aba1e60)
  1 bookmark removed
  $ sl log -G -T '{desc} {bookmarks}\n'
  o  F
  │
  @  E2
  │
  o  C
  │
  o  B
  │
  o  A
