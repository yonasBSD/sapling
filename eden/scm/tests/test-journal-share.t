
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

# Journal extension test: tests the share extension support

  $ export HGIDENTITY=sl
  $ configure modern

  $ cat >> testmocks.py << 'EOF'
  > # mock out util.getuser() and util.makedate() to supply testable values
  > import os
  > from sapling import util
  > def mockgetuser():
  >     return 'foobar'
  > 
  > def mockmakedate():
  >     filename = os.path.join(os.environ['TESTTMP'], 'testtime')
  >     try:
  >         with open(filename, 'rb') as timef:
  >             time = float(timef.read()) + 1
  >     except IOError:
  >         time = 0.0
  >     with open(filename, 'wb') as timef:
  >         timef.write(str(time).encode())
  >     return (time, 0)
  > 
  > util.getuser = mockgetuser
  > util.makedate = mockmakedate
  > EOF

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > journal=
  > share=
  > testmocks=$TESTTMP/testmocks.py
  > [remotenames]
  > rename.default=remote
  > EOF

  $ sl init repo
  $ cd repo
  $ sl bookmark bm
  $ touch file0
  $ sl commit -Am file0-added
  adding file0
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         commit -Am file0-added
  0fd3805711f9  bm        commit -Am file0-added

# A shared working copy initially receives the same bookmarks and working copy

  $ cd ..
  $ sl share repo shared1
  updating working directory
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd shared1
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share repo shared1

# unless you explicitly share bookmarks
# NOTE: This currently does not work. We might want to remove the ability to
# control whether bookmarks are shared or not.

  $ cd ..
  $ sl share --bookmarks repo shared2
  updating working directory
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd shared2
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share --bookmarks repo shared2

# Moving the bookmark in the original repository is only shown in the repository
# that shares bookmarks
# NOTE: This currently does not work. We might want to remove the ability to
# control whether bookmarks are shared or not.

  $ cd ../repo
  $ touch file1
  $ sl commit -Am file1-added
  adding file1
  $ cd ../shared1
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share repo shared1
  $ cd ../shared2
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share --bookmarks repo shared2

# But working copy changes are always 'local'

  $ cd ../repo
  $ sl up 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark bm)
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         up 0
  4f354088b094  .         commit -Am file1-added
  4f354088b094  bm        commit -Am file1-added
  0fd3805711f9  .         commit -Am file0-added
  0fd3805711f9  bm        commit -Am file0-added
  $ cd ../shared2
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share --bookmarks repo shared2
  $ sl up tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl up 0
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl journal
  previous locations of '.':
  0fd3805711f9  up 0
  4f354088b094  up tip
  0fd3805711f9  share --bookmarks repo shared2

# Unsharing works as expected; the journal remains consistent

  $ cd ../shared1
  $ sl unshare
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         share repo shared1
  $ cd ../shared2
  $ sl unshare
  $ sl journal --all
  previous locations of the working copy and bookmarks:
  0fd3805711f9  .         up 0
  4f354088b094  .         up tip
  0fd3805711f9  .         share --bookmarks repo shared2

# New journal entries in the source repo no longer show up in the other working copies

  $ cd ../repo
  $ sl bookmark newbm -r tip
  $ sl journal newbm
  previous locations of 'newbm':
  4f354088b094  bookmark newbm -r tip
  $ cd ../shared2
  $ sl journal newbm
  previous locations of 'newbm':
  no recorded locations

# This applies for both directions

  $ sl bookmark shared2bm -r tip
  $ sl journal shared2bm
  previous locations of 'shared2bm':
  4f354088b094  bookmark shared2bm -r tip
  $ cd ../repo
  $ sl journal shared2bm
  previous locations of 'shared2bm':
  no recorded locations
