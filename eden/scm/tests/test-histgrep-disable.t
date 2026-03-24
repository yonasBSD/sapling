
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Simulate an environment that disables allowfullrepogrep:

  $ export HGIDENTITY=sl
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ setconfig 'histgrep.allowfullrepogrep=False'

# Test histgrep and check that it respects the specified file:

  $ sl init repo
  $ cd repo
  $ mkdir histgrepdir
  $ cd histgrepdir
  $ echo ababagalamaga > histgrepfile1
  $ echo ababagalamaga > histgrepfile2
  $ sl add histgrepfile1
  $ sl add histgrepfile2
  $ sl commit -m 'Added some files'
  $ sl histgrep ababagalamaga histgrepfile1
  histgrepdir/histgrepfile1:*:ababagalamaga (glob)
  $ sl histgrep ababagalamaga
  abort: can't run histgrep on the whole repo, please provide filenames
  (this is disabled to avoid very slow greps over the whole repo)
  [255]

# Now allow allowfullrepogrep:

  $ setconfig 'histgrep.allowfullrepogrep=True'
  $ sl histgrep ababagalamaga
  histgrepdir/histgrepfile1:*:ababagalamaga (glob)
  histgrepdir/histgrepfile2:*:ababagalamaga (glob)
  $ cd ..
