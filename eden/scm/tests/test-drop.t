
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true
UTILS:
  $ reset() {
  >   cd ..
  >   rm -rf a
  >   sl init a
  >   cd a
  > }

TEST: incomplete requirements handling (required extension excluded)
  $ sl init a
  $ cd a
  $ enable drop

  $ sl drop 1
  extension rebase not found
  abort: required extensions not detected
  [255]

SETUP: Properly setup all required extensions
  $ enable rebase drop

TEST: handling no revision provided to drop
  $ sl drop
  abort: no revision to drop was provided
  [255]

TEST: aborting when drop called on root changeset
  $ sl debugbuilddag +1
  $ sl log -G -T '{desc|firstline}'
  o  r0
  
  $ sl drop -r 'desc(r0)'
  abort: root changeset cannot be dropped
  [255]

  $ sl log -G -T '{desc|firstline}'
  o  r0
  
RESET and SETUP
  $ reset
  $ enable rebase drop

TEST: dropping changeset in the middle of the stack
  $ sl debugbuilddag +4 -m
  $ sl log -G -T '{desc|firstline}'
  o  r3
  │
  o  r2
  │
  o  r1
  │
  o  r0
  
  $ sl drop -r 'desc(r2)'
  Dropping changeset c175ba: r2
  rebasing c034855f2b01 "r3"
  merging mf
  $ sl log -G -T '{desc|firstline}'
  o  r3
  │
  o  r1
  │
  o  r0
  
TEST: abort when more than one revision provided
  $ sl drop -r 1 4
  abort: only one revision can be dropped at a time
  [255]

RESET and SETUP
  $ reset
  $ enable rebase drop

TEST: dropping a changest with child changesets
  $ sl debugbuilddag -m "+5 *3 +2"
  $ sl log -G -T '{desc|firstline}'
  o  r7
  │
  o  r6
  │
  o  r5
  │
  │ o  r4
  │ │
  │ o  r3
  ├─╯
  o  r2
  │
  o  r1
  │
  o  r0
  
  $ sl drop 'desc(r2)'
  Dropping changeset 37d4c1: r2
  rebasing e76b6544a13a "r5"
  merging mf
  rebasing 4905937520ff "r6"
  merging mf
  rebasing 2c7cfba83429 "r7"
  merging mf
  rebasing a422badec216 "r3"
  merging mf
  rebasing b762560d23fd "r4"
  merging mf
  $ sl log -G -T '{desc|firstline}'
  o  r4
  │
  o  r3
  │
  │ o  r7
  │ │
  │ o  r6
  │ │
  │ o  r5
  ├─╯
  o  r1
  │
  o  r0
TEST: aborting drop on merge changeset

  $ sl checkout 'max(desc(r3))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl merge 'max(desc(r7))'
  merging mf
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl commit -m "merge"
  $ sl log -G -T '{desc|firstline}'
  @    merge
  ├─╮
  │ │ o  r4
  │ ├─╯
  │ o  r3
  │ │
  o │  r7
  │ │
  o │  r6
  │ │
  o │  r5
  ├─╯
  o  r1
  │
  o  r0
  $ sl drop 'desc(merge)'
  abort: merge changeset cannot be dropped
  [255]

TEST: abort when dropping a public changeset
  $ sl debugmakepublic -r 'desc(r1)'
  $ sl drop 'desc(r1)'
  abort: public changeset which landed cannot be dropped
  [255]

RESET and SETUP
  $ reset
  $ enable rebase drop

TEST: dropping a changeset with merge conflict
  $ sl debugbuilddag -o +4
  $ sl log -G -T '{desc|firstline}'
  o  r3
  │
  o  r2
  │
  o  r1
  │
  o  r0
  
  $ sl drop 'desc(r1)'
  Dropping changeset 2a8ed6: r1
  rebasing 3d69e4d36b46 "r2"
  merging of
  warning: 1 conflicts while merging of! (edit, then use 'sl resolve --mark')
  conflict occurred during drop: please fix it by running 'sl rebase --continue', and then re-run 'sl drop'
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
