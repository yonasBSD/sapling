
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ export HGIDENTITY=sl
  $ newclientrepo
  $ setconfig 'ui.gitignore=1'

  $ cat > .gitignore << 'EOF'
  > *.tmp
  > build/
  > EOF

  $ mkdir build exp
  $ cat > build/.gitignore << 'EOF'
  > !*
  > EOF

  $ cat > exp/.gitignore << 'EOF'
  > !i.tmp
  > EOF

  $ touch build/libfoo.so t.tmp Makefile exp/x.tmp exp/i.tmp

  $ sl status
  ? .gitignore
  ? Makefile
  ? exp/.gitignore
  ? exp/i.tmp

# Test global ignore files

  $ cat > $TESTTMP/globalignore << 'EOF'
  > *.pyc
  > EOF

  $ touch x.pyc

  $ sl status
  ? .gitignore
  ? Makefile
  ? exp/.gitignore
  ? exp/i.tmp
  ? x.pyc

  $ sl status --config 'ui.ignore.global=$TESTTMP/globalignore'
  ? .gitignore
  ? Makefile
  ? exp/.gitignore
  ? exp/i.tmp

# Test directory patterns only match directories.

  $ cat > .gitignore << 'EOF'
  > *.tmp
  > build*/
  > EOF

  $ mkdir buildstuff

  $ touch buildstuff/output builddocs.txt

# x.pyc disappears w/ fsmonitor because the above "status" removes it from the treestate.
# We don't track ignored files in the treestate by default.
  $ sl status
  ? .gitignore
  ? Makefile
  ? builddocs.txt
  ? exp/.gitignore
  ? exp/i.tmp
  ? x.pyc (no-fsmonitor !)

# Test exclusion patterns

  $ cat > .gitignore << 'EOF'
  > /*
  > !/build
  > EOF

  $ rm -rf build/
  $ mkdir build
  $ touch build/libfoo.so t.tmp Makefile

  $ sl status
  ? build/libfoo.so
  $ sl status
  ? build/libfoo.so
