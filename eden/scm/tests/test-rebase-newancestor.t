
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable rebase
  $ readconfig <<EOF
  > [revsetalias]
  > dev=desc("dev")
  > def=desc("def")
  > EOF

  $ sl init repo
  $ cd repo

  $ echo A > a
  $ echo >> a
  $ sl ci -Am A
  adding a

  $ echo B > a
  $ echo >> a
  $ sl ci -m B

  $ echo C > a
  $ echo >> a
  $ sl ci -m C

  $ sl up -q -C 'desc(A)'

  $ echo D >> a
  $ sl ci -Am AD

  $ tglog
  @  3878212183bd 'AD'
  │
  │ o  30ae917c0e4f 'C'
  │ │
  │ o  0f4f7cb4f549 'B'
  ├─╯
  o  1e635d440a73 'A'
  
  $ sl rebase -s 'desc(B)' -d 'desc(AD)'
  rebasing 0f4f7cb4f549 "B"
  merging a
  rebasing 30ae917c0e4f "C"
  merging a

  $ tglog
  o  25773bc4b4b0 'C'
  │
  o  c09015405f75 'B'
  │
  @  3878212183bd 'AD'
  │
  o  1e635d440a73 'A'
  

  $ cd ..


Test rebasing of merges with ancestors of the rebase destination - a situation
that often happens when trying to recover from repeated merging with a mainline
branch.

The test case creates a dev branch that contains a couple of merges from the
default branch. When rebasing to the default branch, these merges would be
merges with ancestors on the same branch. The merges _could_ contain some
interesting conflict resolutions or additional changes in the merge commit, but
that is mixed up with the actual merge stuff and there is in general no way to
separate them.

Note: The dev branch contains _no_ changes to f-default. It might be unclear
how rebasing of ancestor merges should be handled, but the current behavior
with spurious prompts for conflicts in files that didn't change seems very
wrong.

The branches are emulated using commit messages.

  $ sl init ancestor-merge
  $ cd ancestor-merge

  $ drawdag <<'EOS'
  >        default4
  >        |
  >        | devmerge2
  >        |/|
  > default3 |
  >        | |
  >        | devmerge1
  >        |/|
  > default2 |
  >        | |
  >        | dev2
  >        | |
  >        | dev1
  >        |/
  >        default1
  > EOS
  $ cp -R . ../ancestor-merge-2

Full rebase all the way back from branching point:

  $ sl rebase -r 'only(dev,def)' -d $default4 --config ui.interactive=True << EOF
  > c
  > EOF
  rebasing 1e48f4172d62 "dev1"
  rebasing aeae94a564c6 "dev2"
  rebasing da5b1609fcb1 "devmerge1"
  note: not rebasing da5b1609fcb1, its destination (rebasing onto) commit already has all its changes
  rebasing bea5bcfda5f9 "devmerge2"
  note: not rebasing bea5bcfda5f9, its destination (rebasing onto) commit already has all its changes
  $ tglog
  o  f66b059fae0f 'dev2'
  │
  o  1073bfc4c1ed 'dev1'
  │
  o  22e5a3eb70f1 'default4'
  │
  o  a51061c4b2cb 'default3'
  │
  o  dfbdae6572c4 'default2'
  │
  o  6ee4113c6616 'default1'
  
Grafty cherry picking rebasing:

  $ cd ../ancestor-merge-2

  $ sl rebase -r 'children(only(dev,def))' -d $default4 --config ui.interactive=True << EOF
  > c
  > EOF
  rebasing aeae94a564c6 "dev2"
  rebasing da5b1609fcb1 "devmerge1"
  note: not rebasing da5b1609fcb1, its destination (rebasing onto) commit already has all its changes
  rebasing bea5bcfda5f9 "devmerge2"
  note: not rebasing bea5bcfda5f9, its destination (rebasing onto) commit already has all its changes
  $ tglog
  o  9cdc50ee9a9d 'dev2'
  │
  o  22e5a3eb70f1 'default4'
  │
  o  a51061c4b2cb 'default3'
  │
  │ o  1e48f4172d62 'dev1'
  │ │
  o │  dfbdae6572c4 'default2'
  ├─╯
  o  6ee4113c6616 'default1'
  
  $ cd ..


Test order of parents of rebased merged with un-rebased changes as p1.

  $ sl init parentorder
  $ cd parentorder
  $ touch f
  $ sl ci -Aqm common
  $ touch change
  $ sl ci -Aqm change
  $ touch target
  $ sl ci -Aqm target
  $ sl up -qr 'desc(common)'
  $ touch outside
  $ sl ci -Aqm outside
  $ sl merge -qr 'desc(change)'
  $ sl ci -m 'merge p1 3=outside p2 1=ancestor'
  $ sl par
  commit:      6990226659be
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     merge p1 3=outside p2 1=ancestor
  
  $ sl up -qr 'desc(change)'
  $ sl merge -qr f59da8fc0fcf04d44bb0390e824516ed9979b69f
  $ sl ci -qm 'merge p1 1=ancestor p2 3=outside'
  $ sl par
  commit:      a57575f79074
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     merge p1 1=ancestor p2 3=outside
  
  $ tglog
  @    a57575f79074 'merge p1 1=ancestor p2 3=outside'
  ├─╮
  │ │ o  6990226659be 'merge p1 3=outside p2 1=ancestor'
  ╭─┬─╯
  │ o  f59da8fc0fcf 'outside'
  │ │
  │ │ o  a60552eb93fb 'target'
  ├───╯
  o │  dd40c13f7a6f 'change'
  ├─╯
  o  02f0f58d5300 'common'
  
  $ sl rebase -r 'desc("p1 3=outside")' -d 'desc(target)'
  rebasing 6990226659be "merge p1 3=outside p2 1=ancestor"
  $ sl tip
  commit:      cca50676b1c5
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     merge p1 3=outside p2 1=ancestor
  
  $ sl rebase -r 'desc("p1 1=ancestor")' -d 'desc(target)'
  rebasing a57575f79074 "merge p1 1=ancestor p2 3=outside"
  $ sl tip
  commit:      f9daf77ffe76
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     merge p1 1=ancestor p2 3=outside
  
  $ tglog
  @    f9daf77ffe76 'merge p1 1=ancestor p2 3=outside'
  ├─╮
  │ │ o  cca50676b1c5 'merge p1 3=outside p2 1=ancestor'
  ╭─┬─╯
  │ o  f59da8fc0fcf 'outside'
  │ │
  o │  a60552eb93fb 'target'
  │ │
  o │  dd40c13f7a6f 'change'
  ├─╯
  o  02f0f58d5300 'common'
  
rebase of merge of ancestors

  $ sl up -qr 'desc(target)'
  $ sl merge -qr 'desc(outside)-desc(merge)'
  $ echo 'other change while merging future "rebase ancestors"' > other
  $ sl ci -Aqm 'merge rebase ancestors'
  $ sl rebase -d 'desc("merge p1 1")' -v
  rebasing 4c5f12f25ebe "merge rebase ancestors"
  note: merging f9daf77ffe76+ and 4c5f12f25ebe using bids from ancestors a60552eb93fb and f59da8fc0fcf
  
  calculating bids for ancestor a60552eb93fb
  resolving manifests
  
  calculating bids for ancestor f59da8fc0fcf
  resolving manifests
  
  auction for merging merge bids
   other: consensus for g
  end of auction
  
  getting other
  committing files:
  other
  committing manifest
  committing changelog
  rebase merging completed
  rebase completed
  $ tglog
  @  113755df812b 'merge rebase ancestors'
  │
  o    f9daf77ffe76 'merge p1 1=ancestor p2 3=outside'
  ├─╮
  │ │ o  cca50676b1c5 'merge p1 3=outside p2 1=ancestor'
  ╭─┬─╯
  │ o  f59da8fc0fcf 'outside'
  │ │
  o │  a60552eb93fb 'target'
  │ │
  o │  dd40c13f7a6f 'change'
  ├─╯
  o  02f0f58d5300 'common'
  
Due to the limitation of 3-way merge algorithm (1 merge base), rebasing a merge
may include unwanted content:

  $ sl init $TESTTMP/dual-merge-base1
  $ cd $TESTTMP/dual-merge-base1
  $ sl debugdrawdag <<'EOS'
  >   F
  >  /|
  > D E
  > | |
  > B C
  > |/
  > A Z
  > |/
  > R
  > EOS
  $ sl rebase -r D+E+F -d Z
  rebasing 5f2c926dfecf "D" (D)
  rebasing b296604d9846 "E" (E)
  rebasing caa9781e507d "F" (F)
  abort: rebasing caa9781e507d will include unwanted changes from d6003a550c2c or c1e6b162678d
  [255]

The warning does not get printed if there is no unwanted change detected:

  $ sl init $TESTTMP/dual-merge-base2
  $ cd $TESTTMP/dual-merge-base2
  $ sl debugdrawdag <<'EOS'
  >   D
  >  /|
  > B C
  > |/
  > A Z
  > |/
  > R
  > EOS
  $ sl rebase -r B+C+D -d Z
  rebasing c1e6b162678d "B" (B)
  rebasing d6003a550c2c "C" (C)
  rebasing c8f78076273e "D" (D)
  $ sl manifest -r 'desc(D)'
  B
  C
  R
  Z

The merge base could be different from old p1 (changed parent becomes new p1):

  $ sl init $TESTTMP/chosen-merge-base1
  $ cd $TESTTMP/chosen-merge-base1
  $ sl debugdrawdag <<'EOS'
  >   F
  >  /|
  > D E
  > | |
  > B C Z
  > EOS
  $ sl rebase -r D+F -d Z
  rebasing 004dc1679908 "D" (D)
  rebasing 4be4cbf6f206 "F" (F)
  $ sl manifest -r 'desc(F)'
  C
  D
  E
  Z
  $ sl log -r 'max(desc(F))^' -T '{desc}\n'
  D

  $ sl init $TESTTMP/chosen-merge-base2
  $ cd $TESTTMP/chosen-merge-base2
  $ sl debugdrawdag <<'EOS'
  >   F
  >  /|
  > D E
  > | |
  > B C Z
  > EOS
  $ sl rebase -r E+F -d Z
  rebasing 974e4943c210 "E" (E)
  rebasing 4be4cbf6f206 "F" (F)
  $ sl manifest -r 'desc(F)'
  B
  D
  E
  Z
  $ sl log -r 'max(desc(F))^' -T '{desc}\n'
  E
