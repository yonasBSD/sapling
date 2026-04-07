
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ cd $TESTTMP
  $ setconfig 'format.dirstate=2'

  $ newrepo
  $ echo file1 > file1
  $ echo file2 > file2
  $ mkdir -p dira dirb
  $ echo file3 > dira/file3
  $ echo file4 > dirb/file4
  $ echo file5 > dirb/file5
  $ sl ci -q -Am base

# Test debugpathcomplete with just normal files

  $ sl debugpathcomplete f
  file1
  file2
  $ sl debugpathcomplete -f d
  dira/file3
  dirb/file4
  dirb/file5

# Test debugpathcomplete with removed files

  $ sl rm dirb/file5
  $ sl debugpathcomplete -r d
  dirb
  $ sl debugpathcomplete -fr d
  dirb/file5
  $ sl rm dirb/file4
  $ sl debugpathcomplete -n d
  dira

# Test debugpathcomplete with merges

  $ cd ..
  $ newrepo
  $ drawdag << 'EOS'
  >   D     # A/filenormal = 1
  >   |\    # B/filep1 = 1
  >   B C   # B/filemerged = 1
  >   |/    # C/filep2 = 1
  >   A     # C/filemerged = 2
  >         # D/filemerged = 12
  > EOS
  $ sl up -q $D
  $ sl debugpathcomplete f
  filemerged
  filenormal
  filep1
  filep2
