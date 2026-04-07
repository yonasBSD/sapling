
#require no-eden


  $ disable amend
  $ configure mutation-norecord
  $ setconfig commands.update.check=none

Avoid "\r" in messages:

  $ cat > crlf.py << 'EOF'
  > from sapling import extensions, util
  > def uisetup(ui):
  >     extensions.wrapfunction(util, 'tonativeeol', lambda _orig, x: x)
  > EOF
  $ setconfig extensions.nonativecrlf=~/crlf.py

Repo:

  $ newrepo
  $ drawdag << 'EOS'
  > B  # B/B=B\n
  > |
  > A  # A/A=A\n
  > EOS

Cannot amend null:

  $ sl ci --amend -m x
  abort: cannot amend null changeset
  (no changeset checked out)
  [255]

Refuse to amend public csets:

  $ sl up -Cq $B
  $ cp -R . ../repo-public
  $ sl -R ../repo-public debugmakepublic .
  $ sl -R ../repo-public ci --amend
  abort: cannot amend public changesets
  (see 'sl help phases' for details)
  [255]

Nothing to amend:

  $ sl ci --amend -m 'B'
  nothing changed
  [1]

Amending changeset with changes in working dir:
(and check that --message does not trigger an editor)

  $ cat >> $HGRCPATH <<EOF
  > [hooks]
  > pretxncommit.foo = sh -c "echo \\"pretxncommit \$HG_NODE\\"; sl id -r \$HG_NODE"
  > EOF

  $ echo a >> A
  $ HGEDITOR='sh "`pwd`/editor.sh"' sl commit --amend -m 'amend base1'
  pretxncommit 217e580a9218a74044be7970e41021181317b52b
  217e580a9218

  $ echo '%unset pretxncommit.foo' >> $HGRCPATH

  $ sl diff -c .
  diff -r 4a2df7238c3b -r 217e580a9218 A
  --- a/A	Thu Jan 01 00:00:00 1970 +0000
  +++ b/A	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,2 @@
   A
  +a
  diff -r 4a2df7238c3b -r 217e580a9218 B
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/B	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +B
  $ sl log -Gr 'all()' -T '{desc}'
  @  amend base1
  │
  o  A
  

Check proper abort for empty message

  $ cat > editor.sh << '__EOF__'
  > #!/bin/sh
  > echo "" > "$1"
  > __EOF__

  $ echo a >> A
  $ HGEDITOR='sh "`pwd`/editor.sh"' sl commit --amend
  transaction abort! (?)
  rollback completed (?)
  abort: empty commit message
  [255]

Add new file along with modified existing file:

  $ echo C >> C
  $ sl add -q C
  $ sl ci --amend -m 'amend base1 new file'

Remove file that was added in amended commit:
(and test logfile option)
(and test that logfile option do not trigger an editor)

  $ sl rm C
  $ echo 'amend base1 remove new file' > ../logfile
  $ HGEDITOR='sh "`pwd`/editor.sh"' sl ci --amend --logfile ../logfile

  $ sl cat C
  [1]

No changes, just a different message:

  $ sl ci --amend -m 'no changes, new message'

  $ sl diff -c .
  diff -r 4a2df7238c3b -r 80f3c49eb411 A
  --- a/A	Thu Jan 01 00:00:00 1970 +0000
  +++ b/A	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,3 @@
   A
  +a
  +a
  diff -r 4a2df7238c3b -r 80f3c49eb411 B
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/B	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,1 @@
  +B

Disable default date on commit so when -d isn't given, the old date is preserved:

  $ echo '[defaults]' >> $HGRCPATH
  $ echo 'commit=' >> $HGRCPATH

Test -u/-d:

  $ cat > .sl/checkeditform.sh <<EOF
  > env | grep HGEDITFORM
  > true
  > EOF

  $ HGEDITOR="sh .sl/checkeditform.sh" sl ci --amend -u foo -d '1 0'
  HGEDITFORM=commit.amend.normal

  $ echo a >> A
  $ sl ci --amend -u foo -d '1 0'

  $ sl log -r .
  commit:      815553afc946
  user:        foo
  date:        Thu Jan 01 00:00:01 1970 +0000
  summary:     no changes, new message
  

Open editor with old commit message if a message isn't given otherwise:

  $ cat > editor.sh << '__EOF__'
  > #!/bin/sh
  > cat "$1"
  > echo "another precious commit message" > "$1"
  > __EOF__

at first, test saving last-message.txt

  $ cat > .sl/config << '__EOF__'
  > [hooks]
  > pretxncommit.test-saving-last-message = false
  > __EOF__

  $ rm -f .sl/last-message.txt
  $ sl commit --amend -m "message given from command line"
  transaction abort! (?)
  rollback completed (?)
  abort: pretxncommit.test-saving-last-message hook exited with status 1
  [255]

  $ cat .sl/last-message.txt
  message given from command line (no-eol)

  $ rm -f .sl/last-message.txt

  $ HGEDITOR='sh "`pwd`/editor.sh"' sl commit --amend
  no changes, new message
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: foo
  SL: added B
  SL: changed A
  transaction abort! (?)
  rollback completed (?)
  abort: pretxncommit.test-saving-last-message hook exited with status 1
  [255]

  $ cat .sl/last-message.txt
  another precious commit message

  $ cat > .sl/config << '__EOF__'
  > [hooks]
  > pretxncommit.test-saving-last-message =
  > __EOF__

then, test editing custom commit message

  $ HGEDITOR='sh "`pwd`/editor.sh"' sl commit --amend
  no changes, new message
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: foo
  SL: added B
  SL: changed A

Same, but with changes in working dir (different code path):

  $ echo a >> A
  $ HGEDITOR='sh "`pwd`/editor.sh"' sl commit --amend
  another precious commit message
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: foo
  SL: added B
  SL: changed A

  $ rm editor.sh
  $ sl log -r . 
  commit:      642ea5add1ce
  user:        foo
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     another precious commit message

Moving bookmarks, preserve active bookmark:

  $ newrepo
  $ drawdag << 'EOS'
  > a
  > EOS
  $ sl book -r $a book1
  $ sl book -r $a book2
  $ sl up -q book1
  $ sl ci --amend -m 'move bookmarks'
  $ sl book
   transaction abort! (?)
   rollback completed (?)
   * book1                     919d9f835a8e
     book2                     919d9f835a8e

abort does not loose bookmarks
(note: with fsmonitor, transaction started before checking commit message)


Restore global hgrc

  $ cat >> $HGRCPATH <<EOF
  > [defaults]
  > commit=-d '0 0'
  > EOF

Refuse to amend during a merge:

  $ newrepo
  $ drawdag <<'EOS'
  > Y Z
  > |/
  > X
  > EOS
  $ sl up -q $Y
  $ sl merge -q $Z
  $ sl ci --amend
  abort: cannot amend while merging
  [255]

Refuse to amend if there is a merge conflict (issue5805):

  $ newrepo
  $ drawdag <<'EOS'
  > Y  # Y/X=Y
  > |
  > X
  > EOS
  $ sl up -q $X
  $ echo c >> X
  $ sl up $Y -t :fail -q
  [1]
  $ sl resolve -l
  U X

  $ sl ci --amend
  abort: unresolved merge state
  (use 'sl resolve' to continue or
       'sl goto --clean' to abort - WARNING: will destroy uncommitted changes)
  [255]

Follow copies/renames (including issue4405):

  $ newrepo
  $ drawdag <<'EOS'
  > B   # B/B=A (renamed from A)
  > |
  > A
  > EOS

  $ sl up -q $B
  $ echo 1 >> B
  $ sl ci --amend -m 'B-amended'
  $ sl log -r . -T '{file_copies}\n'
  B (A)

  $ sl mv B C
  $ sl ci --amend -m 'C'
  $ sl log -r . -T '{file_copies}\n'
  C (A)

Move added file (issue3410):

  $ newrepo
  $ drawdag <<'EOS'
  > A
  > EOS

  $ sl up -q $A
  $ sl mv A B
  $ sl ci --amend -m 'B'
  $ sl log -r . --template "{file_copies}\n"
  

Obsolete information

  $ sl log -r 'predecessors(.)' --hidden -T '{desc}\n'
  A
  B

Amend a merge. Make it trickier by including renames.

  $ newrepo
  $ drawdag << 'EOS'
  >      # D/D=3
  > D    # C/D=2
  > |\   # B/D=1
  > B C  # B/B=X (renamed from X)
  > | |  # C/C=Y (renamed from Y)
  > X Y
  > EOS

  $ sl up -q $D
  $ sl debugrename B
  B renamed from X:44f0fe2c7b2f8e25d302364ca8d50f37f9bfb143
  $ sl debugrename C
  C renamed from Y:949988db577d2987b8dc29aeb0467aad77fd2005

  $ echo 4 >> D
  $ sl mv B B2
  $ sl mv C C2
  $ sl commit --amend -m D2
  $ sl log -r. -T '{desc}\n'
  D2
  $ sl cat -r. D
  34

  $ sl debugrename B2
  B2 renamed from B:668baf98ee11de8040fa6e9d9b477cb85157750a
  $ sl debugrename C2
  C2 renamed from C:9eeb74a40ee18c256903a5b1d572e0debc1f4cb8

Undo renames

  $ sl mv B2 B
  $ sl mv C2 C
  $ sl commit --amend -m D3
  $ sl debugrename B
  B renamed from X:44f0fe2c7b2f8e25d302364ca8d50f37f9bfb143
  $ sl debugrename C
  C renamed from Y:949988db577d2987b8dc29aeb0467aad77fd2005

Undo merge conflict resolution

  $ sl log -GT '{desc}\n' -f D
  @    D3
  ├─╮
  │ o  C
  │ │
  │ ~
  │
  o  B
  │
  ~

 (This is suboptimal. It should only show B without D4)
  $ printf 1 > D
  $ sl commit --amend -m D4
  $ sl log -GT '{desc}\n' -f D
  @    D4
  ├─╮
  │ o  C
  │ │
  │ ~
  │
  o  B
  │
  ~

  $ printf 2 > D
  $ sl commit --amend -m D4
  $ sl log -GT '{desc}\n' -f D
  o  C
  │
  ~

Amend a merge, with change/deletion conflict.
Sadly, this test shows internals are inconsistent.

  $ newrepo
  $ drawdag << 'EOS'
  >        # E/A=D
  >   E    # E/B=C
  >   |\   # C/A=(removed)
  >   C D  # C/B=C
  >   |/   # D/A=D
  >   |    # D/B=(removed)
  >  /|
  > A B
  > EOS

  $ sl files -r $E
  A
  B

  $ sl up -q $E

  $ sl log -f -T '{desc}' -G A
  o    D
  ├─╮
  │ │
  │ ~
  │
  o  A
  
  $ sl log -f -T '{desc}' -G B
  o    C
  ├─╮
  │ │
  │ ~
  │
  o  B
  
  $ sl log -r. -T '{files}'

  $ sl rm A B
  $ sl ci --amend -m E2
  $ sl log --removed -f -T '{desc}' -G A
  o    D
  ├─╮
  │ │
  │ ~
  │
  │ o  C
  ╭─┤
  │ │
  │ ~
  │
  o  A
  
  $ sl log --removed -f -T '{desc}' -G B
  @    E2
  ├─╮
  │ o    D
  │ ├─╮
  │ │ │
  │ │ ~
  │ │
  o │  C
  ├─╮
  │ │
  ~ │
    │
    o  B
  

 Undo the removal

  $ printf C > B
  $ printf D > A
  $ sl ci --amend -m E3
  $ sl log -fr tip -T '{desc}' -G A
  o    D
  ├─╮
  │ │
  │ ~
  │
  o  A
  
  $ sl log -fr tip -T '{desc}' -G B
  o    C
  ├─╮
  │ │
  │ ~
  │
  o  B
  

  $ sl log -r. -T '{files}'
  B (no-eol)

Test that amend with --edit invokes editor forcibly

  $ newrepo
  $ echo A | sl debugdrawdag
  $ sl up -q A

  $ HGEDITOR=cat sl commit --amend -m "editor should be suppressed"
  $ sl log -r. -T '{desc}\n'
  editor should be suppressed

  $ HGEDITOR=cat sl commit --amend -m "editor should be invoked" --edit
  editor should be invoked
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: bookmark 'A'
  SL: added A

  $ sl log -r. -T '{desc}\n'
  editor should be invoked

Test that "diff()" in committemplate works correctly for amending

  $ newrepo
  $ cat >> .sl/config <<EOF
  > [committemplate]
  > changeset.commit.amend = {desc}\n
  >     SL: M: {file_mods}
  >     SL: A: {file_adds}
  >     SL: R: {file_dels}
  >     {splitlines(diff()) % '{slprefix}: {line}\n'}
  > EOF

  $ echo A | sl debugdrawdag
  $ sl up -q A

  $ HGEDITOR=cat sl commit --amend -e -m "expecting diff of A"
  expecting diff of A
  
  SL: M: 
  SL: A: A
  SL: R: 
  SL: diff -r 000000000000 A
  SL: --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  SL: +++ b/A	Thu Jan 01 00:00:00 1970 +0000
  SL: @@ -0,0 +1,1 @@
  SL: +A
  SL: \ No newline at end of file

#if execbit

Test if amend preserves executable bit changes

  $ newrepo
  $ drawdag <<'EOS'
  > B
  > |
  > A
  > EOS
  $ sl up -q $B
  $ chmod +x A
  $ sl ci -m chmod
  $ sl ci --amend -m "chmod amended"
  $ sl ci --amend -m "chmod amended second time"
  $ sl log -p --git -r .
  commit:      b4aab18bba3e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     chmod amended second time
  
  diff --git a/A b/A
  old mode 100644
  new mode 100755
  
#endif

Test amend with file inclusion options
--------------------------------------

These tests ensure that we are always amending some files that were part of the
pre-amend commit. We want to test that the remaining files in the pre-amend
commit were not changed in the amended commit. We do so by performing a diff of
the amended commit against its parent commit.

  $ newrepo testfileinclusions
  $ echo a > a
  $ echo b > b
  $ sl commit -Aqm "Adding a and b"

Only add changes to a particular file
  $ echo a >> a
  $ echo b >> b
  $ sl commit --amend -I a
  $ sl diff --git -r null -r .
  diff --git a/a b/a
  new file mode 100644
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,2 @@
  +a
  +a
  diff --git a/b b/b
  new file mode 100644
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,1 @@
  +b

  $ echo a >> a
  $ sl commit --amend b
  $ sl diff --git -r null -r .
  diff --git a/a b/a
  new file mode 100644
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,2 @@
  +a
  +a
  diff --git a/b b/b
  new file mode 100644
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,2 @@
  +b
  +b

Exclude changes to a particular file
  $ echo b >> b
  $ sl commit --amend -X a
  $ sl diff --git -r null -r .
  diff --git a/a b/a
  new file mode 100644
  --- /dev/null
  +++ b/a
  @@ -0,0 +1,2 @@
  +a
  +a
  diff --git a/b b/b
  new file mode 100644
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,3 @@
  +b
  +b
  +b

Check the addremove flag
  $ echo c > c
  $ rm a
  $ sl commit --amend -A
  removing a
  adding c
  $ sl diff --git -r null -r .
  diff --git a/b b/b
  new file mode 100644
  --- /dev/null
  +++ b/b
  @@ -0,0 +1,3 @@
  +b
  +b
  +b
  diff --git a/c b/c
  new file mode 100644
  --- /dev/null
  +++ b/c
  @@ -0,0 +1,1 @@
  +c
