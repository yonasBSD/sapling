#require no-eden

First test uncommited changes that should not conflict
  $ newclientrepo <<EOF
  > C
  > |
  > B
  > |
  > A
  > EOF
  $ sl go -q $C
  $ echo added > added
  $ sl add added
  $ echo modifiy > B
  $ sl rm A
  $ touch untracked

  $ sl st
  M B
  A added
  R A
  ? untracked

  $ sl go -q $B

  $ sl st
  M B
  A added
  R A
  ? untracked

Then test --clean works for different types of conflicts
  $ newclientrepo <<EOF
  >    # C/added2 = added2
  >    # C/added1 = added1
  > C  # C/changed = changed
  > |  # C/removed = (removed)
  > B
  > |
  > A  # A/removed =
  >    # A/changed =
  > EOF
  $ sl go -q $B
  $ echo conflict > added1
  $ echo conflict > added2
  $ sl add added2
  $ echo conflict > changed
  $ echo conflict > removed
  $ echo leaveme > added3
  $ sl add added3

  $ sl st
  M removed
  A added2
  A added3
  ? added1
  ? changed

  $ sl go -q $C
  abort: 4 conflicting file changes:
   added1
   added2
   changed
   removed
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]

  $ sl go -q -C $C

  $ sl st
  ? added3
