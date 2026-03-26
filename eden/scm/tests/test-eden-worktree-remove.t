
#require eden

  $ export HGIDENTITY=sl
  $ setconfig worktree.enabled=true

setup backing repo with linked worktrees

  $ newclientrepo myrepo
  $ touch file.txt
  $ sl add file.txt
  $ sl commit -m "init"
  $ sl worktree add $TESTTMP/linked1
  created linked worktree at $TESTTMP/linked1
  $ sl worktree add $TESTTMP/linked2 --label "feature-x"
  created linked worktree at $TESTTMP/linked2
  $ sl worktree add $TESTTMP/linked_from_subdir
  created linked worktree at $TESTTMP/linked_from_subdir

test worktree remove - missing PATH argument

  $ sl worktree remove
  abort: usage: sl worktree remove PATH
  [255]

test worktree remove - cannot remove main with linked worktrees

  $ sl worktree remove $TESTTMP/myrepo -y
  abort: cannot remove a main worktree with linked worktrees
  [255]

test worktree remove - subdirectory path gives clear error

  $ mkdir -p $TESTTMP/myrepo/subdir
  $ cd $TESTTMP/myrepo/subdir
  $ sl worktree remove . -y
  abort: $TESTTMP/myrepo/subdir is not the root of checkout $TESTTMP/myrepo, not removing
  [255]
  $ cd $TESTTMP/myrepo

test worktree remove - basic remove

  $ sl worktree remove $TESTTMP/linked_from_subdir -y
  removed $TESTTMP/linked_from_subdir
  $ test -d $TESTTMP/linked_from_subdir
  [1]

test worktree remove - list after remove shows fewer entries

  $ sl worktree list
    linked  $TESTTMP/linked1
    linked  $TESTTMP/linked2   feature-x
  * main    $TESTTMP/myrepo

test worktree remove - with --keep

  $ sl worktree add $TESTTMP/keep_me
  created linked worktree at $TESTTMP/keep_me
  $ sl worktree remove $TESTTMP/keep_me --keep -y
  unlinked $TESTTMP/keep_me
  $ test -d $TESTTMP/keep_me
  $ sl worktree list
    linked  $TESTTMP/linked1
    linked  $TESTTMP/linked2   feature-x
  * main    $TESTTMP/myrepo

clean up kept checkout
  $ EDENFSCTL_ONLY_RUST=true eden rm -y $TESTTMP/keep_me > /dev/null 2>&1

test worktree remove --all

  $ sl worktree remove --all -y
  removed $TESTTMP/linked1
  removed $TESTTMP/linked2

test worktree remove - group dissolved after all linked removed

  $ sl worktree list
  this worktree is not part of a group
