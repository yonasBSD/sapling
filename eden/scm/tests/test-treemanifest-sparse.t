
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# test interaction between sparse and treemanifest (sparse file listing)

  $ eagerepo
  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > sparse=
  > [remotefilelog]
  > reponame = master
  > cachepath = $PWD/hgcache
  > EOF

# Setup the repository

  $ sl init myrepo
  $ cd myrepo
  $ touch show
  $ touch hide
  $ mkdir -p subdir/foo/spam subdir/bar/ham hiddensub/foo hiddensub/bar
  $ touch subdir/foo/spam/show
  $ touch subdir/bar/ham/hide
  $ touch hiddensub/foo/spam
  $ touch hiddensub/bar/ham
  $ sl add .
  adding hiddensub/bar/ham
  adding hiddensub/foo/spam
  adding hide
  adding show
  adding subdir/bar/ham/hide
  adding subdir/foo/spam/show
  $ sl commit -m Init
  $ sl sparse include show
  $ sl sparse exclude hide
  $ sl sparse include subdir
  $ sl sparse exclude subdir/foo

# Test cwd

  $ sl sparse cwd
  - hiddensub
  - hide
    show
    subdir
  $ cd subdir
  $ sl sparse cwd
    bar
  - foo
  $ sl sparse include foo
  $ sl sparse cwd
    bar
    foo
