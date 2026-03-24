#require git no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ . $TESTDIR/git.sh

Prepare bundle

  $ sl init --git gitrepo1
  $ cd gitrepo1
  $ drawdag << 'EOS'
  >   F   # F/A=E\nA\nB\nF\n
  >   |\
  >   C E
  >   | | # E/A=E\nA\n
  >   B D # B/A=A\nB\n
  >   |/
  >   A   # A/A=A\n
  > EOS

  $ sl log -Gr "::$F" -T '{desc} {node|short}'
  o    F bfade98091ae
  ├─╮
  │ o  E 70890f98a4b5
  │ │
  o │  C 1548fb7ff897
  │ │
  │ o  D e25920a53417
  │ │
  o │  B 30f1a476cd24
  ├─╯
  o  A 495f16b0d4d4
  

Test annotate

  $ sl annotate -c -r $F A
  70890f98a4b5: E
  495f16b0d4d4: A
  30f1a476cd24: B
  bfade98091ae: F

Annotate with reverted change

  $ cd
  $ sl init --git gitrepo2
  $ cd gitrepo2
  $ drawdag << 'EOS'
  > C    # C/A=1
  > :    # B/A=2
  > A    # A/A=1
  > EOS

  $ sl log -Gr: -T '{node|short} {desc}'
  o  41d55b9f0404 C
  │
  o  10241ba6dc94 B
  │
  o  9da411510468 A

  $ sl blame -c -r 'desc(C)' A
  41d55b9f0404: 1

Annotate with deleted change

  $ cd
  $ sl init --git gitrepo3
  $ cd gitrepo3
  $ drawdag << 'EOS'
  >      # D/A=1\n2\n3\n
  > D    # C/A=1\n2\n
  > :    # B/A=(removed)
  > A    # A/A=1\n
  > EOS

  $ sl log -Gr: -T '{node|short} {desc}'
  o  2dd295356a89 D
  │
  o  1be61213744b C
  │
  o  606fa5b617bc B
  │
  o  26347a4a7d12 A

  $ sl blame -c -r 'desc(D)' A
  26347a4a7d12: 1
  1be61213744b: 2
  2dd295356a89: 3
