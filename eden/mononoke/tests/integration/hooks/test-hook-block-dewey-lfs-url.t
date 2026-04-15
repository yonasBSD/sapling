# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"
  $ hook_test_setup \
  > block_dewey_lfs_url

Commit that does not touch .lfsconfig should pass

  $ hg up -q tip
  $ mkcommit somefile
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Commit with .lfsconfig that has an allowed URL should pass

  $ echo "[lfs]" > .lfsconfig
  $ echo "	url = https://lfs.example.com" >> .lfsconfig
  $ hg ci -Aqm "allowed lfs url"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Commit with .lfsconfig that has no lfs.url should pass

  $ echo "[core]" > .lfsconfig
  $ echo "	repositoryformatversion = 0" >> .lfsconfig
  $ hg ci -Aqm "no lfs url"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Commit with .lfsconfig pointing to dewey-lfs should be rejected

  $ echo "[lfs]" > .lfsconfig
  $ echo "	url = https://dewey-lfs.vip.facebook.com" >> .lfsconfig
  $ hg ci -Aqm "dewey lfs url"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  remote: Command failed
  remote:   Error:
  remote:     hooks failed:
  remote:     block_dewey_lfs_url for *: The .lfsconfig file sets lfs.url to "https://dewey-lfs.vip.facebook.com". The hardcoded dewey-lfs.vip.facebook.com URL must be removed as part of the Dewey LFS to Mononoke LFS migration tracked in S629462. Hardcoding an lfs.url for the internal LFS server is no longer required at Meta. Please remove the lfs.url setting from .lfsconfig. (glob)
  abort: unexpected EOL, expected netstring digit
  [255]
  $ hg hide -q .

Commit with dewey-lfs URL with trailing slash should also be rejected

  $ echo "[lfs]" > .lfsconfig
  $ echo "	url = https://dewey-lfs.vip.facebook.com/" >> .lfsconfig
  $ hg ci -Aqm "dewey lfs url trailing slash"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  remote: Command failed
  remote:   Error:
  remote:     hooks failed:
  remote:     block_dewey_lfs_url for *: The .lfsconfig file sets lfs.url to "https://dewey-lfs.vip.facebook.com/". The hardcoded dewey-lfs.vip.facebook.com URL must be removed as part of the Dewey LFS to Mononoke LFS migration tracked in S629462. Hardcoding an lfs.url for the internal LFS server is no longer required at Meta. Please remove the lfs.url setting from .lfsconfig. (glob)
  abort: unexpected EOL, expected netstring digit
  [255]
  $ hg hide -q .

Commit with dewey-lfs URL in mixed case should also be rejected

  $ echo "[lfs]" > .lfsconfig
  $ echo "	url = https://Dewey-LFS.VIP.Facebook.com" >> .lfsconfig
  $ hg ci -Aqm "dewey lfs url mixed case"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  remote: Command failed
  remote:   Error:
  remote:     hooks failed:
  remote:     block_dewey_lfs_url for *: The .lfsconfig file sets lfs.url to "https://Dewey-LFS.VIP.Facebook.com". The hardcoded dewey-lfs.vip.facebook.com URL must be removed as part of the Dewey LFS to Mononoke LFS migration tracked in S629462. Hardcoding an lfs.url for the internal LFS server is no longer required at Meta. Please remove the lfs.url setting from .lfsconfig. (glob)
  abort: unexpected EOL, expected netstring digit
  [255]
  $ hg hide -q .
