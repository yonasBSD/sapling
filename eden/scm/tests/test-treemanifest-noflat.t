
#require no-eden


  $ export HGIDENTITY=sl
  $ setconfig devel.segmented-changelog-rev-compat=true

  $ configure mutation-norecord
  $ . "$TESTDIR/library.sh"

This file tests that normal mercurial operations never read the flat manifests


  $ cat >> $TESTTMP/flatcheck.py <<EOF
  > from __future__ import print_function
  > import sys, traceback
  > from sapling import extensions, manifest
  > def uisetup(ui):
  >     extensions.wrapfunction(manifest.manifestrevlog, 'revision', readmf)
  > def readmf(orig, self, nodeorrev, **kwargs):
  >     if nodeorrev != -1:
  >         print('read flat manifest', file=sys.stderr)
  >         stack = traceback.extract_stack()
  >         print(''.join(traceback.format_list(stack[-3:-2])), file=sys.stderr)
  >     return orig(self, nodeorrev, **kwargs)
  > EOF

  $ hginit master
  $ cd master
  $ cat >> .sl/config <<EOF
  > [remotefilelog]
  > server=True
  > shallowtrees=True
  > EOF
  $ cd ..
  $ sl clone -q ssh://user@dummy/master client

- Add a bunch of files so the manifest is large enough to use deltas
  $ cd master
  $ echo a >> a
  $ echo a >> b
  $ echo a >> c
  $ echo a >> d
  $ echo a >> e
  $ echo a >> f
  $ echo a >> g
  $ echo a >> h
  $ sl commit -Aqm 'add a-f'
  $ echo a >> a
  $ sl commit -Aqm 'modify a'

  $ cd ../client
  $ cat >> .sl/config <<EOF
  > [extensions]
  > flatcheck=$TESTTMP/flatcheck.py
  > 
  > [remotefilelog]
  > reponame=master
  > 
  > [treemanifest]
  > autocreatetrees=True
  > EOF

  $ sl pull -q -r 0
  $ sl pull -q -r 1
  $ sl up 'desc(add)'
  8 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo a >> b && sl commit -Aqm 'modify b'
  $ sl rebase -d 77dc854aeab9a59885f87fa57bfeddbb73b23443 -r 'max(desc(modify))'
  rebasing 667a26a14261 "modify b"
