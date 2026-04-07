
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Make sure the sparse extension does not break functionality when it gets
# loaded in a non-sparse repository.
# First create a base repository with sparse enabled.

  $ eagerepo
  $ sl init base
  $ cd base
  $ cat > .sl/config << 'EOF'
  > [extensions]
  > sparse=
  > journal=
  > EOF

  $ echo a > file1
  $ echo x > file2
  $ sl ci -Aqm initial
  $ cd ..

# Now create a shared working copy that is not sparse.

  $ sl --config 'extensions.share=' share base shared
  updating working directory
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd shared
  $ cat > .sl/config << 'EOF'
  > [extensions]
  > share=
  > sparse=!
  > journal=
  > EOF

# Make sure "sl diff" works in the non-sparse working directory.

  $ echo z >> file1
  $ sl diff
  diff -r 1f02e070b36e file1
  --- a/file1	Thu Jan 01 00:00:00 1970 +0000
  +++ b/file1	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,2 @@
   a
  +z
