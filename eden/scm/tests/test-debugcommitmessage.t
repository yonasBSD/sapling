
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Set up extension

  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > debugcommitmessage=
  > EOF

# Set up repo

  $ sl init repo
  $ cd repo

# Test extension

  $ sl debugcommitmessage
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: no files changed
  $ sl debugcommitmessage --config 'committemplate.changeset.commit.normal.normal=Test Specific Message\n'
  Test Specific Message
  $ sl debugcommitmessage --config 'committemplate.changeset.commit=Test Generic Message\n'
  Test Generic Message
  $ sl debugcommitmessage commit.amend.normal --config 'committemplate.changeset.commit=Test Generic Message\n'
  Test Generic Message
  $ sl debugcommitmessage randomform --config 'committemplate.changeset.commit=Test Generic Message\n'
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: no files changed
