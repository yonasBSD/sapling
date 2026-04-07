
#require no-eden


  $ eagerepo
  $ enable rebase

Rebasing D onto B detaching from C (one commit):

  $ sl init a1
  $ cd a1

  $ drawdag <<EOF
  > D
  > |
  > C B
  > |/
  > A
  > EOF

  $ sl rebase -s $D -d $B
  rebasing e7b3f00ed42e "D"

  $ sl log -G --template "{phase} '{desc}' {branches}\n"
  o  draft 'D'
  │
  │ o  draft 'C'
  │ │
  o │  draft 'B'
  ├─╯
  o  draft 'A'
  
  $ sl manifest --rev tip
  A
  B
  D

  $ cd ..


Rebasing D onto B detaching from C (two commits):

  $ sl init a2
  $ cd a2

  $ drawdag <<EOF
  > E
  > |
  > D
  > |
  > C B
  > |/
  > A
  > EOF

  $ sl rebase -s $D -d $B
  rebasing e7b3f00ed42e "D"
  rebasing 69a34c08022a "E"

  $ tglog
  o  ee79e0744528 'E'
  │
  o  10530e1d72d9 'D'
  │
  │ o  dc0947a82db8 'C'
  │ │
  o │  112478962961 'B'
  ├─╯
  o  426bada5c675 'A'
  
  $ sl manifest --rev tip
  A
  B
  D
  E

  $ cd ..

Rebasing C onto B using detach (same as not using it):

  $ sl init a3
  $ cd a3

  $ drawdag <<EOF
  > D
  > |
  > C B
  > |/
  > A
  > EOF

  $ sl rebase -s $C -d $B
  rebasing dc0947a82db8 "C"
  rebasing e7b3f00ed42e "D"

  $ tglog
  o  7375f3dbfb0f 'D'
  │
  o  bbfdd6cb49aa 'C'
  │
  o  112478962961 'B'
  │
  o  426bada5c675 'A'
  
  $ sl manifest --rev tip
  A
  B
  C
  D

  $ cd ..


Rebasing D onto B detaching from C and collapsing:

  $ sl init a4
  $ cd a4

  $ drawdag <<EOF
  > E
  > |
  > D
  > |
  > C B
  > |/
  > A
  > EOF

  $ sl rebase --collapse -s $D -d $B
  rebasing e7b3f00ed42e "D"
  rebasing 69a34c08022a "E"

  $ sl  log -G --template "{phase} '{desc}' {branches}\n"
  o  draft 'Collapsed revision
  │  * D
  │  * E'
  │ o  draft 'C'
  │ │
  o │  draft 'B'
  ├─╯
  o  draft 'A'
  
  $ sl manifest --rev tip
  A
  B
  D
  E

  $ cd ..

Rebasing across null as ancestor
  $ sl init a5
  $ cd a5

  $ drawdag <<EOF
  > E
  > |
  > D
  > |
  > C
  > |
  > A B
  > EOF

  $ sl rebase -s $C -d $B
  rebasing dc0947a82db8 "C"
  rebasing e7b3f00ed42e "D"
  rebasing 69a34c08022a "E"

  $ tglog
  o  e3d0c70d606d 'E'
  │
  o  e9153d36a1af 'D'
  │
  o  a7ac28b870a8 'C'
  │
  o  fc2b737bb2e5 'B'
  
  o  426bada5c675 'A'
  
  $ sl rebase -d 'desc(B)' -s 'desc(D)'
  rebasing e9153d36a1af "D"
  rebasing e3d0c70d606d "E"
  $ tglog
  o  2c24e540eccd 'E'
  │
  o  73f786ed52ff 'D'
  │
  │ o  a7ac28b870a8 'C'
  ├─╯
  o  fc2b737bb2e5 'B'
  
  o  426bada5c675 'A'
  
  $ cd ..

Verify that target is not selected as external rev (issue3085)

  $ sl init a6
  $ cd a6

  $ drawdag <<EOF
  > H
  > | G
  > |/|
  > F E
  > |/
  > A
  > EOF
  $ sl up -q $G

  $ echo "I" >> E
  $ sl ci -m "I"
  $ export I=$(sl log -r . -T "{node}")
  $ sl merge $H
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m "Merge"
  $ echo "J" >> F
  $ sl ci -m "J"
  $ tglog
  @  c6aaf0d259c0 'J'
  │
  o    0cfbc7e8faaf 'Merge'
  ├─╮
  │ o  b92d164ad3cb 'I'
  │ │
  o │  4ea5b230dea3 'H'
  │ │
  │ o  c6001eacfde5 'G'
  ╭─┤
  o │  8908a377a434 'F'
  │ │
  │ o  7fb047a69f22 'E'
  ├─╯
  o  426bada5c675 'A'
  
  $ sl rebase -s $I -d $H --collapse --config ui.merge=internal:other
  rebasing b92d164ad3cb "I"
  rebasing 0cfbc7e8faaf "Merge"
  rebasing c6aaf0d259c0 "J"

  $ tglog
  @  65079693dac4 'Collapsed revision
  │  * I
  │  * Merge
  │  * J'
  o  4ea5b230dea3 'H'
  │
  │ o  c6001eacfde5 'G'
  ╭─┤
  o │  8908a377a434 'F'
  │ │
  │ o  7fb047a69f22 'E'
  ├─╯
  o  426bada5c675 'A'
  

  $ sl log --rev tip
  commit:      65079693dac4
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Collapsed revision
  

  $ cd ..

Ensure --continue restores a correct state (issue3046) and phase:
  $ sl init a7
  $ cd a7

  $ drawdag <<EOF
  > C B
  > |/
  > A
  > EOF
  $ sl up -q $C
  $ echo 'B2' > B
  $ sl ci -A -m 'B2'
  adding B

  $ sl rebase -s . -d $B --config ui.merge=internal:fail
  rebasing 17b4880d2402 "B2"
  merging B
  warning: 1 conflicts while merging B! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl resolve --all -t internal:local
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase -c
  rebasing 17b4880d2402 "B2"
  note: not rebasing 17b4880d2402, its destination (rebasing onto) commit already has all its changes
  $ sl  log -G --template "{phase} '{desc}' {branches}\n"
  o  draft 'C'
  │
  │ @  draft 'B'
  ├─╯
  o  draft 'A'
  

  $ cd ..
