
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Set up

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH << 'EOF'
  > [experimental]
  > evolution=all
  > [extensions]
  > amend=
  > tweakdefaults=
  > EOF

# Test sl bookmark works with hidden commits

  $ sl init repo1
  $ cd repo1
  $ touch a
  $ sl commit -A a -m a
  $ echo 1 >> a
  $ sl commit a -m a1
  $ sl hide da7a5140a611 -q
  $ sl bookmark b -r da7a5140a611 -q

# Same test but with remotenames enabled

  $ sl bookmark b2 -r da7a5140a611 -q
