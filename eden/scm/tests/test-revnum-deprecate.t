
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ sl init
  $ sl debugdrawdag << 'EOS'
  > C
  > |
  > B
  > |
  > A
  > EOS

  $ setconfig 'devel.legacy.revnum=warn'

# use revnum directly

  $ sl log -r 0 -T '.\n'
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 0) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

# negative revnum

  $ sl goto -r -2
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  hint[revnum-deprecate]: Local revision numbers (ex. -2) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

# revset operators

  $ sl log -r 1+2 -T '.\n'
  .
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 1) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

  $ sl log -r '::2' -T '.\n'
  .
  .
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 2) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

  $ sl log -r 2-1 -T '.\n'
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 2) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

# revset functions

  $ sl log -r 'parents(2)' -T '.\n'
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 2) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

  $ sl log -r 'sort(2+0)' -T '.\n'
  .
  .
  hint[revnum-deprecate]: Local revision numbers (ex. 2) are being deprecated and will stop working in the future. Please use commit hashes instead.
  hint[hint-ack]: use 'sl hint --ack revnum-deprecate' to silence these hints

# abort

  $ setconfig 'devel.legacy.revnum=abort'
  $ sl up 0
  abort: local revision number is disabled in this repo
  [255]

# smartlog revset

  $ enable smartlog
  $ sl log -r 'smartlog()' -T.
  ...
  $ sl log -r 'smartlog(1)' -T.
  abort: local revision number is disabled in this repo
  [255]

# phase

  $ sl phase
  112478962961147124edd43549aedd1a335e44bf: draft
