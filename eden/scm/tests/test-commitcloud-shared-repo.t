
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo
  $ enable commitcloud share
  $ setconfig commitcloud.servicetype=local commitcloud.servicelocation=$TESTTMP commitcloud.subscription_enabled=true
Don't try connecting to the real hosts's scm_daemon.
  $ setconfig commitcloud.scm_daemon_tcp_port=-1

  $ newclientrepo source
  $ cd
  $ sl share -q source dest1
  $ sl share -q source dest2

  $ sl -R dest1 cloud join --debug
  commitcloud: this repository is now connected to the 'user/test/default' workspace for the 'source_server' repo
  commitcloud: synchronizing 'source_server' with 'user/test/default'
  commitcloud: nothing to upload
  commitcloud local service: get_references for current version 0
  commitcloud local service: get_references for current version 0
  commitcloud local service: update_references to 1 (0 heads, 0 bookmarks, 0 remote bookmarks)
  commitcloud: commits synchronized
  finished in * sec (glob)
  commitcloud: check: writing subscription * (glob)

  $ sl -R dest2 cloud join --debug
  commitcloud: this repository has been already connected to the 'user/test/default' workspace for the 'source_server' repo
  commitcloud: synchronizing 'source_server' with 'user/test/default'
  commitcloud: nothing to upload
  commitcloud local service: get_references for current version 1
  commitcloud local service: get_references for versions from 0 to 1
  commitcloud: commits synchronized
  finished in * sec (glob)

Verify we only have a single subscription written out:
  $ cat .commitcloud/joined/*
  [commitcloud]
  workspace=user/test/default
  repo_name=source_server
  repo_root=$TESTTMP/source/.sl

Simulate an old subscription entry for the non-shared dest1/.sl path:
  $ echo whatever > .commitcloud/joined/b9a9896242218b02f0c4c98819375e4d

Old subscriptions are cleaned up automatically:
  $ sl -R dest1 cloud sync --debug
  commitcloud: synchronizing 'source_server' with 'user/test/default'
  commitcloud: nothing to upload
  commitcloud local service: get_references for current version 1
  commitcloud local service: get_references for versions from 0 to 1
  commitcloud: commits synchronized
  finished in * sec (glob)

  $ cat ~/.commitcloud/joined/*
  [commitcloud]
  workspace=user/test/default
  repo_name=source_server
  repo_root=$TESTTMP/source/.sl
  whatever

Can leave:
  $ echo whatever > .commitcloud/joined/b9a9896242218b02f0c4c98819375e4d
  $ sl -R dest1 cloud leave --debug
  commitcloud: remove: cleaning up shared subscription * (glob)
  commitcloud: this repository is now disconnected from the 'user/test/default' workspace

Deleted both old and new subscriptions:
  $ ls ~/.commitcloud/joined
  b9a9896242218b02f0c4c98819375e4d

Can rename:
  $ sl -R dest1 cloud join --create -w apple
  commitcloud: this repository is now connected to the 'user/test/apple' workspace for the 'source_server' repo
  commitcloud: synchronizing 'source_server' with 'user/test/apple'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * sec (glob)

Write out old non-shared subscription file:
  $ echo whatever > .commitcloud/joined/e6b1156ad250e44b62e81726deb0ee83
  $ sl -R dest1 cloud rename -d banana
  commitcloud: synchronizing 'source_server' with 'user/test/apple'
  commitcloud: nothing to upload
  commitcloud: commits synchronized
  finished in * sec (glob)
  commitcloud: rename the 'user/test/apple' workspace to 'user/test/banana' for the repo 'source_server'
  commitcloud: rename successful

Only a single subscription remains:
  $ cat ~/.commitcloud/joined/*
  [commitcloud]
  workspace=user/test/banana
  repo_name=source_server
  repo_root=$TESTTMP/source/.sl
  whatever
  whatever
