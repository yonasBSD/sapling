#require no-eden

  $ setconfig devel.segmented-changelog-rev-compat=true
  $ newserver server1
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS
  $ sl bookmark -ir $B master

  $ cd $TESTTMP
  $ clone server1 client1
  $ cd client1

"master" is not lagging after clone:

  $ sl doctor --config doctor.check-lag-threshold=1
  checking internal storage
  revisionstore: repaired
  revisionstore: repaired
  checking commit references
  checking irrelevant draft branches for the workspace 'user/test/default'

Cause "lag" by adding a commit:

  $ drawdag --cwd $TESTTMP/server1 << "EOS"
  > D
  > |
  > tip
  > EOS
  $ sl --cwd $TESTTMP/server1 bookmark -ir tip master -q

  $ drawdag << "EOS"
  > C
  > |
  > tip
  > EOS

  $ sl doctor --config doctor.check-lag-threshold=1
  checking internal storage
  revisionstore: repaired
  checking commit references
  master might be lagging, running pull
  checking irrelevant draft branches for the workspace 'user/test/default'

The latest master is pulled:

  $ sl log -r master -T '{desc}\n'
  D

Test too many names:

  $ sl debugremotebookmark name1 .
  $ sl debugremotebookmark name2 .
  $ sl debugremotebookmark name3 .
  $ sl log -r 'all()' -T '{desc}: {remotenames}.\n'
  A: .
  B: debugremote/name1 debugremote/name2 debugremote/name3.
  C: .
  D: remote/master.

  $ sl doctor --config doctor.check-too-many-names-threshold=1
  checking internal storage
  checking commit references
  repo has too many (4) remote bookmarks
  (only 1 of them (master) are essential)
  only keep essential remote bookmarks (Yn)? y
  checking irrelevant draft branches for the workspace 'user/test/default'
  $ sl log -r 'all()' -T '{desc}: {remotenames}.\n'
  A: .
  B: .
  C: .
  D: remote/master.

Test less relevant branches:

  $ cd $TESTTMP
  $ clone server1 client2
  $ cd client2
  $ sl log -Gr 'all()' -T '{desc} {remotenames}'
  @  D remote/master
  │
  o  B
  │
  o  A
  
  $ drawdag << 'EOS'
  > F3  G3 G4 # amend: G3 -> G4
  > |   | /
  > F2  G2
  > |   |
  > F1  G1
  > |  /
  > tip
  > EOS

  $ sl doctor
  checking internal storage
  checking commit references
  checking irrelevant draft branches for the workspace 'user/test/default'

Changing the author, F branch becomes "less relevant". G is okay as it has
local modifications.

  $ HGUSER='Foo <f@o.o>' sl doctor
  checking internal storage
  checking commit references
  checking irrelevant draft branches for the workspace 'user/test/default'
  1 branches (627e777a207b) look less relevant
  hide those branches (Yn)? y

  $ sl log -Gr 'all()' -T '{desc} {remotenames}'
  o  G4
  │
  o  G2
  │
  o  G1
  │
  @  D remote/master
  │
  o  B
  │
  o  A
  
