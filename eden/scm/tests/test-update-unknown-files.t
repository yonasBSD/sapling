  $ export HGIDENTITY=sl
  $ setconfig experimental.nativecheckout=true
  $ setconfig commands.update.check=noconflict

  $ newclientrepo myrepo

  $ echo a > a
  $ sl add a
  $ sl commit -m 'A'
  $ echo a > b
  $ sl add b
  $ sl commit -m 'B'
  $ sl up 'desc(A)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo x > b
  $ sl up 'desc(B)'
  abort: 1 conflicting file changes:
   b
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
  $ sl up 'desc(B)' --clean
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl up 'desc(A)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo a > b
  $ sl up 'desc(B)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ rm b
  $ sl rm b
  $ echo X > B
TODO(sggutier): investigate why different combinations of eden / no-Windows behave differently
  $ sl add B
  warning: possible case-folding collision for B (no-eden !)
  adding b (windows !) (eden !)
  $ sl commit -m 'C'
  $ sl up 'desc(B)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ ls
  a
  b
  $ echo Z > a
  $ sl up 'desc(C)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl status
  M a
  $ sl up null
  abort: 1 conflicting file changes:
   a
  (commit, shelve, goto --clean to discard all your changes, or goto --merge to merge them)
  [255]
#if no-windows
Replacing symlink with content
  $ mkdir x
  $ echo zzz > x/a
  $ ln -s x y
  $ sl add x/a y
  $ sl commit -m 'D'
  $ rm y
  $ sl rm y
  $ mkdir y
  $ echo yyy > y/a
  $ sl add y/a
  $ sl commit -m 'E'
  $ sl up 'desc(D)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ cat y/a
  zzz
  $ sl up 'desc(E)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ cat y/a
  yyy
#endif
