#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ configure mutation
  $ enable rebase strip
  $ setconfig phases.publish=0

Create repo a:

  $ newrepo a
  $ drawdag <<'EOS'
  > H
  > |
  > | G
  > |/|
  > F |
  > | |
  > | E
  > |/
  > | D
  > | |
  > | C
  > | |
  > | B
  > |/
  > A
  > EOS

  $ cd $TESTTMP

Rebasing B onto H and collapsing changesets:


  $ cp -r a a1
  $ cd a1
  $ sl go -q $D

  $ cat > $TESTTMP/editor.sh <<EOF
  > echo "==== before editing"
  > cat \$1
  > echo "===="
  > echo "edited manually" >> \$1
  > EOF
  $ HGEDITOR="sh $TESTTMP/editor.sh" sl rebase --collapse -e --dest $H
  rebasing 112478962961 "B"
  rebasing 26805aba1e60 "C"
  rebasing f585351a92f8 "D"
  ==== before editing
  Collapsed revision
  * B
  * C
  * D
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: added B
  SL: added C
  SL: added D
  ====

  $ sl log -Gr 'all()' -T '{desc}'
  @  Collapsed revision
  │  * B
  │  * C
  │  * D
  │
  │
  │  edited manually
  o  H
  │
  │ o  G
  ╭─┤
  o │  F
  │ │
  │ o  E
  ├─╯
  o  A
  
  $ sl manifest --rev tip
  A
  B
  C
  D
  F
  H

  $ cd $TESTTMP

Rebasing E onto H:

  $ cp -r a a2
  $ cd a2
  $ sl go -q $H

  $ sl rebase --source $E --collapse --dest $H
  rebasing 7fb047a69f22 "E"
  rebasing c6001eacfde5 "G"

  $ sl log -Gr 'all()' -T '{desc}'
  o  Collapsed revision
  │  * E
  │  * G
  │ o  D
  │ │
  @ │  H
  │ │
  │ o  C
  │ │
  o │  F
  │ │
  │ o  B
  ├─╯
  o  A
  
  $ sl manifest --rev tip
  A
  E
  F
  H

  $ cd ..

Rebasing G onto H with custom message:

  $ cp -r a a3
  $ cd a3
  $ sl go -q $H

  $ sl rebase --base 6 -m 'custom message' -d .
  abort: message can only be specified with collapse
  [255]

  $ cat > $TESTTMP/checkeditform.sh <<EOF
  > env | grep HGEDITFORM
  > true
  > EOF
  $ HGEDITOR="sh $TESTTMP/checkeditform.sh" sl rebase --source $E --collapse -m 'custom message' -e --dest $H
  rebasing 7fb047a69f22 "E"
  rebasing c6001eacfde5 "G"
  HGEDITFORM=rebase.collapse

  $ sl log -Gr 'all()' -T '{desc}'
  o  custom message
  │
  │ o  D
  │ │
  @ │  H
  │ │
  │ o  C
  │ │
  o │  F
  │ │
  │ o  B
  ├─╯
  o  A
  
  $ sl manifest --rev tip
  A
  E
  F
  H

  $ cd ..

Create repo b:

  $ newrepo b
  $ drawdag <<'EOS'
  > H
  > |
  > | G
  > | |\
  > | | F
  > | | |
  > | | E
  > | | |
  > | D |  # D/D=D
  > | |\|
  > | C |
  > |/ /
  > | B
  > |/
  > A
  > EOS
  $ cd $TESTTMP


Rebase and collapse - more than one external (fail):

  $ cp -r b b1
  $ cd b1
  $ sl go -q $H

  $ sl rebase -s $C --dest $H --collapse
  abort: unable to collapse on top of 575c4b5ec114, there is more than one external parent: 112478962961, 11abe3fb10b8
  [255]

Rebase and collapse - E onto H:

  $ sl rebase -s $E --dest $H --collapse # root (E) is not a merge
  rebasing 49cb92066bfd "E"
  rebasing 11abe3fb10b8 "F"
  rebasing 202d1982ae8b "G"

  $ sl log -Gr 'all()' -T '{desc}'
  o    Collapsed revision
  ├─╮  * E
  │ │  * F
  │ │  * G
  │ o    D
  │ ├─╮
  @ │ │  H
  │ │ │
  │ │ o  C
  ├───╯
  │ o  B
  ├─╯
  o  A
  
  $ sl manifest --rev tip
  A
  C
  D
  E
  F
  H

Create repo c:

  $ newrepo c
  $ drawdag <<'EOS'
  > I
  > |
  > | H
  > | |\
  > | | G
  > | | |
  > | | F  # F/E=F\n
  > | | |  # F/F=(removed)
  > | | E
  > | | |
  > | D |  # D/D=D
  > | |\|
  > | C |
  > |/ /
  > | B
  > |/
  > A
  > EOS
  $ cd $TESTTMP

Rebase and collapse - E onto I:

  $ cp -r c c1
  $ cd c1
  $ sl go -q $I

  $ sl rebase -s $E --dest $I --collapse # root (E) is not a merge
  rebasing 49cb92066bfd "E"
  rebasing 3cf8a9483881 "F"
  rebasing 066fd31e12b9 "G"
  rebasing c8947cb2e149 "H"

  $ sl log -Gr 'all()' -T '{desc}'
  o    Collapsed revision
  ├─╮  * E
  │ │  * F
  │ │  * G
  │ │  * H
  │ o    D
  │ ├─╮
  @ │ │  I
  │ │ │
  │ │ o  C
  ├───╯
  │ o  B
  ├─╯
  o  A
  
  $ sl manifest --rev tip
  A
  C
  D
  E
  G
  I

  $ sl up tip -q
  $ cat E
  F

Create repo d:

  $ newrepo d
  $ drawdag <<'EOS'
  > F
  > |
  > | E
  > | |\
  > | | D
  > | | |
  > | C |
  > | |/
  > | B
  > |/
  > A
  > EOS
  $ cd $TESTTMP


Rebase and collapse - B onto F:

  $ cp -r d d1
  $ cd d1
  $ sl go -q $F

  $ sl rebase -s $B --collapse --dest $F
  rebasing 112478962961 "B"
  rebasing 26805aba1e60 "C"
  rebasing be0ef73c17ad "D"
  rebasing 02c4367d6973 "E"

  $ sl log -Gr 'all()' -T '{desc}'
  o  Collapsed revision
  │  * B
  │  * C
  │  * D
  │  * E
  @  F
  │
  o  A
  
  $ sl manifest --rev tip
  A
  B
  C
  D
  F

Rebase, collapse and copies

  $ newrepo copies
  $ drawdag << 'EOS'
  > Q   # Q/c=c\n (renamed from f)
  > |   # Q/g=b\n (renamed from e)
  > |
  > P   # P/d=a\n (copied from a)
  > |   # P/e=b\n (renamed from b)
  > |   # P/f=c\n (renamed from c)
  > |
  > | Y # Y/a=a\na\n
  > |/  # Y/b=b\nb\n
  > |   # Y/c=c\nc\n
  > |
  > |   # X/a=a\n
  > X   # X/b=b\n
  >     # X/c=c\n
  >     # drawdag.defaultfiles=false
  > EOS

  $ sl up -q $Q
  $ sl rebase --collapse -d $Y
  rebasing 24b95cf2173d "P"
  merging a and d to d
  merging b and e to e
  merging c and f to f
  rebasing 2ccc3426bf6d "Q"
  merging f and c to c
  merging e and g to g
  $ sl st
  $ sl st --copies --change tip
  A d
    a
  A g
    b
  R b
  $ sl up tip -q
  $ cat c
  c
  c
  $ cat d
  a
  a
  $ cat g
  b
  b
  $ sl log -r . --template "{file_copies}\n"
  d (a)g (b)

  $ sl log -Gr 'all()' -T '{desc}'
  @  Collapsed revision
  │  * P
  │  * Q
  o  Y
  │
  o  X
  
Test collapsing in place

  $ sl rebase --collapse -b . -d $X
  rebasing 71cf332de4cf "Y"
  rebasing 2dddb285069e "Collapsed revision"
  $ sl st --change tip --copies
  M a
  M c
  A d
    a
  A g
    b
  R b
  $ sl up tip -q
  $ cat a
  a
  a
  $ cat c
  c
  c
  $ cat d
  a
  a
  $ cat g
  b
  b
  $ cd $TESTTMP


Test collapsing changes that add then remove a file

  $ sl init collapseaddremove
  $ cd collapseaddremove

  $ touch base
  $ sl commit -Am base
  adding base
  $ touch a
  $ sl commit -Am a
  adding a
  $ sl rm a
  $ touch b
  $ sl commit -Am b
  adding b
  $ sl book foo
  $ sl rebase -d 'desc(base)' -r "max(desc(a))::max(desc(b))" --collapse -m collapsed
  rebasing 6d8d9f24eec3 "a"
  rebasing 1cc73eca5ecc "b" (foo)
  $ sl log -G --template "'{desc}' {bookmarks}"
  @  'collapsed' foo
  │
  o  'base'
  
  $ sl manifest --rev tip
  b
  base

  $ cd $TESTTMP

Test that rebase --collapse will remember message after
running into merge conflict and invoking rebase --continue.

  $ sl init collapse_remember_message
  $ cd collapse_remember_message
  $ touch a
  $ sl add a
  $ sl commit -m "a"
  $ echo "a-default" > a
  $ sl commit -m "a-default"
  $ sl goto -r 3903775176ed42b1458a6281db4a0ccf4d9f287a
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo "a-dev" > a
  $ sl commit -m "a-dev"
  $ sl rebase --collapse -m "a-default-dev" -d 3c8db56a44bcb7c2afe3a7b368ecdd09efaff115
  rebasing 1fb04abbc715 "a-dev"
  merging a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ rm a.orig
  $ sl resolve --mark a
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  rebasing 1fb04abbc715 "a-dev"
  $ sl log
  commit:      925b342b51db
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a-default-dev
  
  commit:      3c8db56a44bc
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a-default
  
  commit:      3903775176ed
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  $ cd ..

Collapsed commits have internal conflict:

  $ newrepo e
  $ drawdag <<'EOS'
  > D
  > |
  > | B # B/foo = foo
  > | | C # C/foo = bar
  > | |/
  > |/
  > A
  > EOS

Rebase should fail due to merge conflict when inmemory=true:

  $ sl rebase -r $B -r $C -d $D --collapse --config rebase.experimental.inmemory=true
  rebasing 02385eab34c0 "C"
  rebasing 15544ab8d64e "B"
  merging foo
  warning: 1 conflicts while merging foo! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
