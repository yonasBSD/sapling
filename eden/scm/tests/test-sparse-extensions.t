
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ setconfig fsmonitor.track-ignore-files=true

  $ eagerepo

# test sparse interaction with other extensions

  $ sl init myrepo
  $ cd myrepo
  $ cat > .sl/config << 'EOF'
  > [extensions]
  > sparse=
  > EOF

  $ printf '[include]\nfoo\n.gitignore\n' > .hgsparse
  $ sl add .hgsparse
  $ sl commit -qm 'Add profile'
  $ sl sparse --enable-profile .hgsparse

#if fsmonitor
# Test fsmonitor integration (if available)

  $ touch .watchmanconfig
  $ echo ignoredir1 >> .gitignore
  $ sl commit -Am ignoredir1
  adding .gitignore
  $ echo ignoredir2 >> .gitignore
  $ sl commit -m ignoredir2

  $ sl sparse reset
  $ sl sparse -I ignoredir1 -I ignoredir2 -I dir1 -I .gitignore

  $ mkdir ignoredir1 ignoredir2 dir1
  $ touch ignoredir1/file ignoredir2/file dir1/file

# Run status twice to compensate for a condition in fsmonitor where it will check
# ignored files the second time it runs, regardless of previous state (ask @sid0)

  $ sl status
  ? dir1/file
  $ sl status
  ? dir1/file

# Test that fsmonitor by default handles .gitignore changes and can "unignore" files.

  $ sl up -q '.^'
  $ sl status
  ? dir1/file
  ? ignoredir2/file
#endif
