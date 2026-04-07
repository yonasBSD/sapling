
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ sl init repo
  $ cd repo

# committing changes

  $ drawdag <<'EOS'
  > N
  > :
  > A
  > EOS

  $ sl bisect -s "! (file('path:E') or file('path:M'))"
  $ cat .sl/bisect.state
  skip revset:! (file('path:E') or file('path:M'))

  $ sl bisect -g $A
  $ sl bisect -b $N
  Testing changeset 9bc730a19041 (13 changesets remaining, ~3 tests)
  5 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bisect -b
  The first bad revision is:
  commit:      9bc730a19041
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     E
  
  Revisions omitted due to the skip option:
  commit:      112478962961
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     B
  
  commit:      26805aba1e60
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     C
  
  commit:      f585351a92f8
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     D
