
#require no-eden


  $ eagerepo

Emulate situations where NEED_CHECK was added to normal files and there should
be a way to remove them.

  $ newrepo
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS
  $ sl up $B -q

Write mtime to treestate

  $ sleep 1

  $ sl status

  $ sl debugtree list
  A: 0100644 1 + EXIST_P1 EXIST_NEXT 
  B: 0100644 1 + EXIST_P1 EXIST_NEXT 

Force the files to have NEED_CHECK bits

  $ sl debugshell -c "
  > with repo.lock(), repo.transaction('needcheck') as tr:
  >     d = repo.dirstate
  >     d.needcheck('A')
  >     d.needcheck('B')
  >     d.write(tr)
  > "
  $ sl debugtree list
  A: 0100644 1 + EXIST_P1 EXIST_NEXT NEED_CHECK 
  B: 0100644 1 + EXIST_P1 EXIST_NEXT NEED_CHECK 

Run status again. NEED_CHECK will disappear.

  $ sl status

  $ sl debugtree list
  A: 0100644 1 + EXIST_P1 EXIST_NEXT 
  B: 0100644 1 + EXIST_P1 EXIST_NEXT 

Enable sparse

  $ enable sparse
  $ sl sparse include A

When removing "B", fsmonitor+treestate will mark it as "NEED_CHECK" instead

  $ sl debugtree list
  A: 0100644 1 + EXIST_P1 EXIST_NEXT 
  B: 0100644 1 + NEED_CHECK  (fsmonitor !)

Force NEED_CHECK on files outside sparse

  $ printf B > B
  $ sl debugshell --config extensions.sparse=! -c "
  > with repo.lock(), repo.transaction('needcheck') as tr:
  >     d = repo.dirstate
  >     d.needcheck('A')
  >     d.normal('B')
  >     d.needcheck('B')
  >     d.write(tr)
  > "

Run "sl status" and NEED_CHECK can be removed:

  $ sleep 1
  $ sl status

Non-fsmonitor skips "B" to save work since it is outside the matcher.
  $ sl debugtree list
  A: 0100644 1 + EXIST_P1 EXIST_NEXT 
  B: 0100644 1 + EXIST_P1 EXIST_NEXT  (fsmonitor !)
  B: 0100644 1 -1 EXIST_P1 EXIST_NEXT NEED_CHECK  (no-fsmonitor !)
