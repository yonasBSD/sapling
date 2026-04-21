
#require no-eden


  $ newclientrepo

audit of .sl

  $ sl add .sl/00changelog.i
  abort: path contains illegal component '.sl': .sl/00changelog.i
  [255]

#if symlink

Symlinks

  $ mkdir a
  $ echo a > a/a
  $ sl ci -Ama
  adding a/a
  $ ln -s a b
  $ echo b > a/b
  $ sl add b/b
  abort: path 'b/b' traverses symbolic link 'b'
  [255]
  $ sl add b

should still fail - maybe

  $ sl add b/b
  abort: path 'b/b' traverses symbolic link 'b'
  [255]

  $ sl commit -m 'add symlink b'


Test symlink traversing when accessing history:
-----------------------------------------------

(build a changeset where the path exists as a directory)

  $ sl up .^
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ mkdir b
  $ echo c > b/a
  $ sl add b/a
  $ sl ci -m 'add directory b'

Test that hg cat does not do anything wrong the working copy has 'b' as directory

  $ sl cat b/a
  c
  $ sl cat -r "desc(directory)" b/a
  c
  $ sl cat -r "desc(symlink)" b/a
  b/a: no such file in rev 940e1c0d7f31
  [1]

Test that hg cat does not do anything wrong the working copy has 'b' as a symlink (issue4749)

  $ sl up 'desc(symlink)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl cat b/a
  b/a: no such file in rev 940e1c0d7f31
  [1]
  $ sl cat -r "desc(directory)" b/a
  c
  $ sl cat -r "desc(symlink)" b/a
  b/a: no such file in rev 940e1c0d7f31
  [1]

#endif

Test symlink traversal on merge:
--------------------------------

#if symlink

set up symlink hell

  $ cd "$TESTTMP"
  $ mkdir merge-symlink-out
  $ newclientrepo
  $ touch base
  $ sl commit -qAm base
  $ ln -s ../merge-symlink-out a
  $ sl commit -qAm 'symlink a -> ../merge-symlink-out'
  $ sl up -q 'desc(base)'
  $ mkdir a
  $ echo not-owned > a/poisoned
  $ sl commit -qAm 'file a/poisoned'
  $ sl log -G -T '{desc}\n'
  @  file a/poisoned
  │
  │ o  symlink a -> ../merge-symlink-out
  ├─╯
  o  base
  

try trivial merge

  $ sl up -qC 'desc(symlink)'
  $ sl merge -q 'desc(file)'
  $ sl st
  M a/poisoned
  ! a
  $ cat a/poisoned
  not-owned
  $ ls ../merge-symlink-out

try rebase onto other revision: cache of audited paths should be discarded,
and the rebase should fail (issue5628)

  $ sl up -qC 'desc(file)'
  $ sl rebase -q -s 'desc(file)' -d 'desc(symlink)' --config extensions.rebase=
  $ cat a/poisoned
  not-owned
  $ ls ../merge-symlink-out

Test symlink traversal on update:
---------------------------------

  $ cd "$TESTTMP"
  $ mkdir update-symlink-out
  $ newclientrepo
  $ ln -s ../update-symlink-out a
  $ sl commit -qAm 'symlink a -> ../update-symlink-out'
  $ sl rm a
  $ mkdir a && echo b > a/b
  $ sl ci -qAm 'file a/b' a/b
  $ sl up -qC 'desc(symlink)'
  $ sl rm a
  $ mkdir a && echo c > a/c
  $ sl ci -qAm 'rm a, file a/c'
  $ sl log -G -T '{desc}\n'
  @  rm a, file a/c
  │
  │ o  file a/b
  ├─╯
  o  symlink a -> ../update-symlink-out
  

try linear update where symlink already exists:

  $ sl up -qC 'desc(symlink)'
  $ sl up -q 'desc("file a/b")'
  $ cat a/b
  b

try linear update including symlinked directory and its content: paths are
audited first by calculateupdates(), where no symlink is created so both
'a' and 'a/b' are taken as good paths. still applyupdates() should fail.

  $ sl up -qC null
  $ sl up -q 'desc("file a/b")'
  $ cat a/b
  b
  $ ls ../update-symlink-out

try branch update replacing directory with symlink, and its content: the
path 'a' is audited as a directory first, which should be audited again as
a symlink.

  $ rm -f a
  $ sl up -qC 'desc(rm)'
  $ sl up -q 'desc("file a/b")'
  $ cat a/b
  b
  $ ls ../update-symlink-out

#endif

Works for .sl repos also

  $ HGIDENTITY=sl newrepo
  $ sl add .sl/00changelog.i
  abort: path contains illegal component '.sl': .sl/00changelog.i
  [255]
