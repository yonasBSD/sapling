
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > arcconfig=$TESTDIR/../sapling/ext/extlib/phabricator/arcconfig.py
  > EOF

# Sanity check expectations when there is no arcconfig

  $ sl init repo
  $ cd repo
  $ sl debugarcconfig
  abort: no .arcconfig found
  [255]

# Show that we can locate and reflect the contents of the .arcconfig from
# the repo dir

  $ echo '{"hello": "world"}' > .arcconfig
  $ sl debugarcconfig
  {"_arcconfig_path": "$TESTTMP/repo", "hello": "world"}

# We expect to see the combination of the user arcrc and the repo rc

  $ echo '{"user": true}' > $HOME/.arcrc
  $ sl debugarcconfig
  {"_arcconfig_path": "$TESTTMP/repo", "hello": "world", "user": true}

# .arcconfig lookup is scoped at $HOME

  $ cd
  $ mkdir -p x/y
  $ echo '{"foo": "bar"}' > x/.arcconfig
  $ cd x/y
  $ sl init
  $ sl debugarcconfig
  {"_arcconfig_path": "$TESTTMP/x", "foo": "bar", "user": true}
  $ HOME=$PWD sl debugarcconfig
  abort: no .arcconfig found
  [255]
