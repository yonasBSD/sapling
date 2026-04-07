
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# debug-args

  $ eagerepo
  $ sl --cwd . debug-args a b
  ["a", "b"]
  $ sl --cwd . debug args a b
  ["a", "b"]

# Aliases

  $ sl --config 'alias.foo-bar=debug-args alias-foo-bar' foo bar 1 2
  ["alias-foo-bar", "1", "2"]
  $ sl --config 'alias.foo-bar=debug-args alias-foo-bar' foo-bar 1 2
  ["alias-foo-bar", "1", "2"]

# If both "foo-bar" and "foo" are defined, then "foo bar" does not resolve to
# "foo-bar".
#
# This is because: Supose we have "add" and "add-only-text" command.
# If the user has a file called "only-text", "add only-text" should probably
# use the "add" command.

  $ sl --config 'alias.foo-bar=debug-args alias-foo-bar' --config 'alias.foo=debug-args alias-foo' foo bar
  ["alias-foo", "bar"]
  $ sl --config 'alias.foo-bar=debug-args alias-foo-bar' --config 'alias.foo=debug-args alias-foo' foo-bar
  ["alias-foo-bar"]
