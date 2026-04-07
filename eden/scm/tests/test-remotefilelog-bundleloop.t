
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ setconfig "remotefilelog.cachepath=$TESTTMP/cache" 'extensions.remotefilelog='

  $ newrepo
  $ echo remotefilelog >> .sl/requires
  $ drawdag << 'EOS'
  > E  # E/X=1 (renamed from Y)
  > |
  > D  # D/Y=3 (renamed from X)
  > |
  > B  # B/X=2
  > |
  > A  # A/X=1
  > EOS

  $ sl bundle --all "$TESTTMP/bundle" --traceback -q

  $ newrepo
  $ echo remotefilelog >> .sl/requires
  $ sl unbundle "$TESTTMP/bundle"
  adding changesets
  adding manifests
  adding file changes
