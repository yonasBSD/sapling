
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

  $ eagerepo
  $ enable morestatus
  $ setconfig morestatus.show=True ui.origbackuppath=.hg/origs
  $ setconfig checkout.use-rust=true

Python utility:

    @command
    def createstate(args):
        """Create an interrupted state resolving 'sl update --merge' conflicts"""
        def createrepo():
            $ newrepo
            $ drawdag << 'EOS'
            > B C
            > |/   # B/A=B\n
            > A
            > EOS
        if not args or args[0] == "update":
            createrepo()
            $ sl up -C $C -q
            $ echo C > A
            $ sl up --merge $B -q
            warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
            [1]
        elif args[0] == "backout":
            createrepo()
            $ drawdag << 'EOS'
            > D  # D/A=D\n
            > |
            > desc(B)
            > EOS
            $ sl up -C $D -q
            $ sl backout $B -q
            warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
            [1]


  $ createstate

# There is only one working parent (which is good):

  $ sl parents -T "{desc}\n"
  B

# 'morestatus' message:

  $ sl status
  M A
  
  # The repository is in an unfinished *update* state.
  # Unresolved merge conflicts (1):
  # 
  #     A
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl goto --continue
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)

# Cannot --continue right now

  $ sl goto --continue
  abort: outstanding merge conflicts
  (use 'sl resolve --list' to list, 'sl resolve --mark FILE' to mark resolved)
  [255]

# 'morestatus' message after resolve
# BAD: The unfinished merge state is confusing and there is no clear way to get out.

  $ sl resolve -m A
  (no more unresolved files)
  continue: sl goto --continue
  $ sl status
  M A
  
  # The repository is in an unfinished *update* state.
  # No unresolved merge conflicts.
  # To continue:                sl goto --continue
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)

# To get rid of the state

  $ sl goto --continue
  $ sl status
  M A

# Test abort flow

  $ createstate

  $ sl goto --clean . -q
  $ sl status

# Test 'sl continue'

  $ sl continue
  abort: nothing to continue
  [255]

  $ createstate

  $ sl continue
  abort: outstanding merge conflicts
  (use 'sl resolve --list' to list, 'sl resolve --mark FILE' to mark resolved)
  [255]

  $ sl resolve -m A
  (no more unresolved files)
  continue: sl goto --continue

  $ sl continue

# Test 'sl continue' in a context that does not implement --continue.
# Choose 'backout' for this test. The 'backout' command does not have
# --continue.

  $ createstate backout

  $ sl continue
  abort: outstanding merge conflicts
  (use 'sl resolve --list' to list, 'sl resolve --mark FILE' to mark resolved)
  [255]
  $ sl resolve --all -t :local
  (no more unresolved files)
  $ sl status
  R B
  
  # The repository is in an unfinished *merge* state.
  # No unresolved merge conflicts.
  # To continue:                sl continue, then sl commit
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)

# The state is confusing, but 'sl continue' can resolve it.

  $ sl continue
  (exiting merge state)
  $ sl status
  R B
