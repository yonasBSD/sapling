
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# test sparse with --verbose and -T json

  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable sparse
  $ sl init myrepo
  $ cd myrepo

  $ echo a > show
  $ echo x > hide
  $ sl ci -Aqm initial

  $ echo b > show
  $ echo y > hide
  $ echo aa > show2
  $ echo xx > hide2
  $ sl ci -Aqm two

# Verify basic --include and reset

  $ sl up -q 'desc(initial)'
  $ sl sparse --include hide -Tjson
  [
   {
    "exclude_rules_added": 0,
    "files_added": 0,
    "files_conflicting": 0,
    "files_dropped": 1,
    "include_rules_added": 1,
    "profiles_added": 0
   }
  ]
  $ sl sparse --clear-rules
  $ sl sparse --include hide --verbose
  calculating actions for refresh
  applying changes to disk (1 actions)
  removing show
  updating dirstate
  Profile # change: 0
  Include rule # change: 1
  Exclude rule # change: 0

  $ sl sparse reset -Tjson
  [
   {
    "exclude_rules_added": 0,
    "files_added": 1,
    "files_conflicting": 0,
    "files_dropped": 0,
    "include_rules_added": -1,
    "profiles_added": 0
   }
  ]
  $ sl sparse --include hide
  $ sl sparse reset --verbose
  calculating actions for refresh
  applying changes to disk (1 actions)
  getting show
  updating dirstate
  Profile # change: 0
  Include rule # change: -1
  Exclude rule # change: 0

# Verifying that problematic files still allow us to see the deltas when forcing:

  $ sl sparse --include 'show*'
  $ touch hide
  $ sl sparse --delete 'show*' --force -Tjson
  pending changes to 'hide'
  [
   {
    "exclude_rules_added": 0,
    "files_added": 0,
    "files_conflicting": 1,
    "files_dropped": 0,
    "include_rules_added": -1,
    "profiles_added": 0
   }
  ]
  $ sl sparse --include 'show*' --force
  pending changes to 'hide'
  $ sl sparse --delete 'show*' --force --verbose
  calculating actions for refresh
  verifying no pending changes in newly included files
  pending changes to 'hide'
  applying changes to disk (1 actions)
  updating dirstate
  Profile # change: 0
  Include rule # change: -1
  Exclude rule # change: 0
