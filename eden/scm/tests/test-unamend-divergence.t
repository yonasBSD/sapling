  $ export HGIDENTITY=sl
  $ enable amend rebase undo

  $ newclientrepo
  $ drawdag <<EOS
  > B   C
  >  \ /
  >   A
  > EOS
  $ sl go -q $C
  $ echo changed > C
  $ sl amend -q
  $ sl rebase -qr . -d $B
  $ sl unamend
  abort: commit was not amended
  (use "sl undo" to undo the last command, or "sl reset COMMIT" to reset to a previous commit, or see "sl journal" to view commit mutations)
  [255]
  $ sl undo -q
  $ sl unamend
  $ sl st
  M C
