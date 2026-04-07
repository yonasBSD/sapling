
#require no-eden


  $ newclientrepo repo
  $ enable undo
  $ echo >> file
  $ sl commit -Aqm "initial commit"
  $ echo >> file
  $ sl commit -Aqm "initial commit"
  $ sl log -r 'olddraft(0)'
  commit:      79344ac2ab8b
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit
  
  commit:      f5a897cc70a1
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit
  
  $ sl log -r 'oldworkingcopyparent(0)'
  commit:      f5a897cc70a1
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit
  
  $ sl log -r . -T '{undonecommits(0)}\n'
  
  $ sl log -r . -T '{donecommits(0)}\n'
  f5a897cc70a18acf06b00febe9ad748ac761067d
  $ sl log -r . -T '{oldworkingcopyparent(0)}\n'
  f5a897cc70a18acf06b00febe9ad748ac761067d
  $ sl undo --preview
  @
  │
  o
  
  undo to *, before commit -Aqm initial commit (glob)

  $ sl undo --keep
  undone to *, before commit -Aqm initial commit (glob)

  $ sl log -r 'olddraft(0)'
  commit:      79344ac2ab8b
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit

  $ sl status
  M file

  $ sl commit -Aqm "recommit after undo --keep"
  $ sl log -r 'olddraft(0)'
  commit:      79344ac2ab8b
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     initial commit
  
  commit:      0109d94c2173
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     recommit after undo --keep


  $ sl undo
  undone to *, before commit -Aqm recommit after undo --keep (glob)
  hint[undo-uncommit-unamend]: undoing commits discards their changes.
  to restore the changes to the working copy, run 'sl revert -r 0109d94c2173 --all'
  in the future, you can use 'sl uncommit' instead of 'sl undo' to keep changes
  hint[hint-ack]: use 'sl hint --ack undo-uncommit-unamend' to silence these hints

  $ sl undo foo
  sl undo: invalid arguments
  (use 'sl undo -h' to get help)
  [255]



