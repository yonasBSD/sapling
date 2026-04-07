#require git no-eden

  $ eagerepo
Test that rebasing in a git repo with conflicts work.

  $ . $TESTDIR/git.sh
  $ setconfig diff.git=true ui.allowemptycommit=true
  $ enable rebase

Prepare the repo

  $ sl init --git repo1
  $ cd repo1
  $ drawdag << 'EOS'
  >         # B/A=0
  > A7  B   # A5/A=3
  >  : /    # A3/A=2
  >  A1     # A1/A=1
  > EOS

Rebase:

  $ sl rebase -r $B -d $A7
  rebasing 5c2dbc94ad6b "B"
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

  $ sl rebase --abort
  rebase aborted

Rebase with merge.printcandidatecommits:

  $ sl rebase -r $B -d $A7 --config merge.printcandidatecommmits=1
  rebasing 5c2dbc94ad6b "B"
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
   2 commits might have introduced this conflict:
    - [ff6d58de9da5] A5
    - [b7b8bbe2022e] A3
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
