
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ export HGIDENTITY=sl
  $ sl init test
  $ cd test
  $ echo a > changed
  $ echo a > removed
  $ echo a > source
  $ sl ci -Am addfiles
  adding changed
  adding removed
  adding source
  $ echo a >> changed
  $ echo a > added
  $ sl add added
  $ sl rm removed
  $ sl cp source copied
  $ sl diff --git > ../unknown.diff

# Test adding on top of an unknown file

  $ sl up -qC 'desc(addfiles)'
  $ sl purge
  $ echo a > added
  $ sl import --no-commit ../unknown.diff
  applying ../unknown.diff
  file added already exists
  1 out of 1 hunks FAILED -- saving rejects to file added.rej
  abort: patch failed to apply
  [255]

# Test modifying an unknown file

  $ sl revert -aq
  $ sl purge
  $ sl rm changed
  $ sl ci -m removechanged
  $ echo a > changed
  $ sl import --no-commit ../unknown.diff
  applying ../unknown.diff
  abort: cannot patch changed: file is not tracked
  [255]

# Test removing an unknown file

  $ sl up -qC 'desc(addfiles)'
  $ sl purge
  $ sl rm removed
  $ sl ci -m removeremoved
  $ echo a > removed
  $ sl import --no-commit ../unknown.diff
  applying ../unknown.diff
  abort: cannot patch removed: file is not tracked
  [255]

# Test copying onto an unknown file

  $ sl up -qC 'desc(addfiles)'
  $ sl purge
  $ echo a > copied
  $ sl import --no-commit ../unknown.diff
  applying ../unknown.diff
  abort: cannot create copied: destination already exists
  [255]

  $ cd ..
