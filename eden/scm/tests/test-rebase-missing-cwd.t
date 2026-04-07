
  $ configure mutation-norecord
#require rmcwd no-eden

Ensure that dirsync does not cause an abort when cwd goes missing

  $ enable rebase dirsync
  $ setconfig phases.publish=False

  $ configure modern
  $ newclientrepo
  $ drawdag <<'EOF'
  >   change    # change/a = a
  >    |
  >    | delete # delete/dir/a = (removed)
  >    | /
  >   base      # base/dir/a = a
  > EOF

  $ sl co -q $change
  $ cd dir

  $ sl rebase -s . -d $delete
  rebasing * "change" (glob)

  $ cd "$TESTTMP/repo1"
  $ sl status

  $ sl log -Gr "all()" -T "{node|short} {desc}"
  @  * change (glob)
  │
  o  * delete (glob)
  │
  o  * base (glob)
  
  $ sl rebase --abort
  abort: no rebase in progress
  [255]
