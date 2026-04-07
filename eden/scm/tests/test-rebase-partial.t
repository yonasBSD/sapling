
#require no-eden


  $ eagerepo
Tests rebasing with part of the rebase set already in the
destination (issue5422)

  $ configure mutation-norecord
  $ enable rebase

  $ rebasewithdag() {
  >   N=$((N + 1))
  >   sl init repo$N && cd repo$N
  >   sl debugdrawdag
  >   sl rebase "$@" && tglog
  >   cd ..
  >   return $r
  > }

Rebase two commits, of which one is already in the right place

  $ rebasewithdag -r C+D -d B <<EOF
  > C
  > |
  > B D
  > |/
  > A
  > EOF
  rebasing b18e25de2cf5 "D" (D)
  already rebased 26805aba1e60 "C" (C)
  o  fe3b4c6498fa 'D' D
  │
  │ o  26805aba1e60 'C' C
  ├─╯
  o  112478962961 'B' B
  │
  o  426bada5c675 'A' A
  
Can collapse commits even if one is already in the right place

  $ rebasewithdag --collapse -r C+D -d B <<EOF
  > C
  > |
  > B D
  > |/
  > A
  > EOF
  rebasing b18e25de2cf5 "D" (D)
  rebasing 26805aba1e60 "C" (C)
  o  a2493f4ace65 'Collapsed revision
  │  * D
  │  * C' C D
  o  112478962961 'B' B
  │
  o  426bada5c675 'A' A
  
Rebase with "holes". The commits after the hole should end up on the parent of
the hole (B below), not on top of the destination (A).

  $ rebasewithdag -r B+D -d A <<EOF
  > D
  > |
  > C
  > |
  > B
  > |
  > A
  > EOF
  already rebased 112478962961 "B" (B)
  rebasing f585351a92f8 "D" (D)
  o  1e6da8103bc7 'D' D
  │
  │ o  26805aba1e60 'C' C
  ├─╯
  o  112478962961 'B' B
  │
  o  426bada5c675 'A' A
  
Abort doesn't lose the commits that were already in the right place

  $ newrepo abort
  $ sl debugdrawdag <<EOF
  > C
  > |
  > B D  # B/file = B
  > |/   # D/file = D
  > A
  > EOF
  $ sl rebase -r C+D -d B
  rebasing ef8c0fe0897b "D" (D)
  merging file
  warning: 1 conflicts while merging file! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl rebase --abort
  rebase aborted
  $ tglog
  o  79f6d6ab7b14 'C' C
  │
  │ o  ef8c0fe0897b 'D' D
  │ │
  o │  594087dbaf71 'B' B
  ├─╯
  o  426bada5c675 'A' A
  
test rebase sapling copy commit can introduce partial changes
  $ newclientrepo partial
  $ drawdag <<'EOS'
  > C    # C/foo/y = 1'\n2\n3\n
  > |    # C/foo/x = 1'\n2\n3\n
  > B    # B/foo/y = 1\n2\n3\n
  > |
  > A    # A/foo/x = 1\n2\n3\n
  >      # A/foo2/x = 1\n2\n3\n
  > EOS
  $ sl go -q $B
  $ ls foo2
  x
  $ sl rm foo2 -q
  $ sl cp foo foo2 -q
  $ sl ci -m 'cp foo foo2'
  $ ls foo2
  x
  y
  $ sl rebase -r . -d $C
  rebasing d62b595077f8 "cp foo foo2"
  merging foo/y and foo2/y to foo2/y
  $ sl log -G -T '{node|short} {desc|firstline}\n'
  @  deee512b4511 cp foo foo2
  │
  o  cb9362f65bb1 C
  │
  o  78fd32924038 B
  │
  o  de0c4b853cce A
rebase introduce partial changes of commit C
  $ sl show
  commit:      deee512b4511
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  files:       foo2/y
  description:
  cp foo foo2
  
  
  diff -r cb9362f65bb1 -r deee512b4511 foo2/y
  --- /dev/null	Thu Jan 01 00:00:00 1970 +0000
  +++ b/foo2/y	Thu Jan 01 00:00:00 1970 +0000
  @@ -0,0 +1,3 @@
  +1'
  +2
  +3
