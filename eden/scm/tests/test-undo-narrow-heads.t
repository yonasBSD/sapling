
#require no-eden


  $ eagerepo
  $ configure mutation
  $ enable undo
  $ setconfig extensions.extralog="$TESTDIR/extralog.py"
  $ setconfig ui.interactive=true

  $ newrepo
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS

  $ drawdag << 'EOS'
  >   C
  >  /
  > A
  > EOS

  $ sl book -r $C book-C
  $ sl undo
  undone to *, before book -r * book-C (glob)
  $ sl undo
  undone to *, before debugdrawdag * (glob)
  $ sl log -GT '{desc}'
  o  B
  │
  o  A
  
  $ sl redo
  undone to *, before undo (glob)
  $ sl log -GT '{desc}'
  o  C
  │
  │ o  B
  ├─╯
  o  A
  
