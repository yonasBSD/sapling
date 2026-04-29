# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"
  $ hook_test_setup \
  > block_mixed_users_changes <( \
  >   cat <<CONF
  > config_json='''{
  >  "users_prefix": "users/"
  > }'''
  > CONF
  > )

  $ hg up -q tip

Only users/ changes - should pass
  $ mkdir -p users/alice
  $ echo "sandbox" > users/alice/test.txt
  $ hg ci -Aqm "users only"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Only non-users/ changes - should pass
  $ echo "prod code" > lib.rs
  $ hg ci -Aqm "non-users only"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark

Mixed changes - should pass (hook is still no-op)
  $ echo "mixed sandbox" > users/alice/mixed.txt
  $ echo "mixed prod" > mixed_prod.rs
  $ hg ci -Aqm "mixed changes"
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark
