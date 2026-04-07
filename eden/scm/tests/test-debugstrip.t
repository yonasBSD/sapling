#modern-config-incompatible

#require no-eden

#inprocess-hg-incompatible
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ configure mutation-norecord

  $ setconfig format.usegeneraldelta=yes

  $ restore() {
  >     sl unbundle -q .sl/strip-backup/*
  >     rm .sl/strip-backup/*
  > }
  $ teststrip() {
  >     sl up -C $1
  >     echo % before update $1, strip $2
  >     sl parents
  >     hg --traceback debugstrip $2
  >     echo % after update $1, strip $2
  >     sl parents
  >     restore
  > }

  $ sl init test
  $ cd test

  $ echo foo > bar
  $ sl ci -Ama
  adding bar

  $ echo more >> bar
  $ sl ci -Amb

  $ echo blah >> bar
  $ sl ci -Amc

  $ sl up 'desc(b)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo blah >> bar
  $ sl ci -Amd

  $ echo final >> bar
  $ sl ci -Ame

  $ sl log
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  commit:      65bd5f99a4a3
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     d
  
  commit:      264128213d29
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  commit:      9ab35a2d17cb
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  

  $ teststrip 'desc(e)' 'desc(e)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % before update desc(e), strip desc(e)
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % after update desc(e), strip desc(e)
  commit:      65bd5f99a4a3
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     d
  
  $ teststrip 'desc(e)' 'desc(d)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % before update desc(e), strip desc(d)
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % after update desc(e), strip desc(d)
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  $ teststrip 'desc(b)' 'desc(e)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % before update desc(b), strip desc(e)
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  % after update desc(b), strip desc(e)
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  $ teststrip 'desc(e)' 'desc(c)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % before update desc(e), strip desc(c)
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  % after update desc(e), strip desc(c)
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  $ teststrip 'desc(c)' 'desc(b)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % before update desc(c), strip desc(b)
  commit:      264128213d29
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  % after update desc(c), strip desc(b)
  commit:      9ab35a2d17cb
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  
  $ teststrip null 'desc(c)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  % before update null, strip desc(c)
  % after update null, strip desc(c)

  $ sl log
  commit:      443431ffac4f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  commit:      65bd5f99a4a3
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     d
  
  commit:      264128213d29
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  commit:      9ab35a2d17cb
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  $ sl up -C 'desc(c)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl parents
  commit:      264128213d29
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  

  $ sl --traceback debugstrip 'desc(c)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl parents
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  $ sl debugbundle .sl/strip-backup/*
  Stream params: {Compression: BZ}
  changegroup -- {nbchanges: 1, version: 02}
      264128213d290d868c54642d13aeaa3675551a78
  phase-heads -- {}
      264128213d290d868c54642d13aeaa3675551a78 draft
  b2x:treegroup2 -- {cache: False, category: manifests, version: 1}
      1 data items, 1 history items
      812d56fc5e4133f1f57fc44bd22c6d9ea0810dcb 
  $ sl unbundle .sl/strip-backup/*
  adding changesets
  adding manifests
  adding file changes
  $ rm .sl/strip-backup/*
  $ sl log --graph
  o  commit:      443431ffac4f
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     e
  │
  o  commit:      65bd5f99a4a3
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     d
  │
  │ o  commit:      264128213d29
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     c
  │
  @  commit:      ef3a871183d7
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     b
  │
  o  commit:      9ab35a2d17cb
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     a
  $ sl up -C 'desc(d)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl merge 'desc(c)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

before strip of merge parent

  $ sl parents
  commit:      65bd5f99a4a3
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     d
  
  commit:      264128213d29
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  $ sl debugstrip 'desc(c)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

after strip of merge parent

  $ sl parents
  commit:      ef3a871183d7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  $ restore

  $ sl up 'desc(c)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -G
  o  commit:      443431ffac4f
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     e
  │
  o  commit:      65bd5f99a4a3
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     d
  │
  │ @  commit:      264128213d29
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     c
  │
  o  commit:      ef3a871183d7
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     b
  │
  o  commit:      9ab35a2d17cb
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     a

2 is parent of 3, only one strip should happen

  $ sl debugstrip "roots(desc(d))" 'desc(e)'
  $ sl log -G
  @  commit:      264128213d29
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     c
  │
  o  commit:      ef3a871183d7
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     b
  │
  o  commit:      9ab35a2d17cb
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     a
  
  $ restore
  $ sl log -G
  o  commit:      443431ffac4f
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     e
  │
  o  commit:      65bd5f99a4a3
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     d
  │
  │ @  commit:      264128213d29
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     c
  │
  o  commit:      ef3a871183d7
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     b
  │
  o  commit:      9ab35a2d17cb
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     a
  
2 different branches: 2 strips

  $ sl debugstrip 'desc(c)' 'desc(e)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -G
  o  commit:      65bd5f99a4a3
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     d
  │
  @  commit:      ef3a871183d7
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     b
  │
  o  commit:      9ab35a2d17cb
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     a
  
  $ restore

2 different branches and a common ancestor: 1 strip

  $ sl debugstrip 'desc(b)' "desc(c)|desc(e)"
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ restore

stripping an empty revset

  $ sl debugstrip "desc(b) and not desc(b)"
  abort: empty revision set
  [255]

Strip adds, removes, modifies with --keep

  $ touch b
  $ sl add b
  $ sl commit -mb
  $ touch c

... with a clean working dir

  $ sl add c
  $ sl rm bar
  $ sl commit -mc
  $ sl status
  $ sl debugstrip --keep tip
  $ sl status
  ! bar
  ? c

... with a dirty working dir

  $ sl add c
  $ sl rm bar
  $ sl commit -mc
  $ sl status
  $ echo b > b
  $ echo d > d
  $ sl debugstrip --keep tip
  $ sl status
  M b
  ! bar
  ? c
  ? d

... after updating the dirstate
  $ sl add c
  $ sl commit -mc
  $ sl rm c
  $ sl commit -mc
  $ sl debugstrip --keep '.^' -q
  $ cd ..

stripping many nodes on a complex graph (issue3299)

  $ sl init issue3299
  $ cd issue3299
  $ sl debugbuilddag -n '@a.:a@b.:b.:x<a@a.:a<b@b.:b<a@a.:a'
  $ sl debugstrip 'not ancestors(x)'

test sl debugstrip -B bookmark

  $ cd ..
  $ sl init bookmarks
  $ cd bookmarks
  $ sl debugbuilddag -n '..<2.*1/2:m<2+3:c<m+3:a<2.:b<m+2:d<2.:e<m+1:f'
  $ sl bookmark -r 'a' 'todelete'
  $ sl bookmark -r 'b' 'B'
  $ sl bookmark -r 'b' 'nostrip'
  $ sl bookmark -r 'c' 'delete'
  $ sl bookmark -r 'd' 'multipledelete1'
  $ sl bookmark -r 'e' 'multipledelete2'
  $ sl bookmark -r 'f' 'singlenode1'
  $ sl bookmark -r 'f' 'singlenode2'
  $ sl book -d a b c d e f m
  $ sl up -C todelete
  7 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark todelete)
  $ sl debugstrip -B nostrip
  bookmark 'nostrip' deleted
  abort: empty revision set
  [255]
  $ sl debugstrip -B todelete
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  bookmark 'todelete' deleted
  $ sl id -ir dcbb326fdec2
  abort: unknown revision 'dcbb326fdec2'!
  [255]
  $ sl bookmarks
     B                         bde800a4ddec
     delete                    ff38c2200f49
     multipledelete1           287656a49854
     multipledelete2           003512c0aeac
     singlenode1               ffd3d95c59c8
     singlenode2               ffd3d95c59c8
  $ sl debugstrip -B multipledelete1 -B multipledelete2
  bookmark 'multipledelete1' deleted
  bookmark 'multipledelete2' deleted
  $ sl id -ir e46a4836065c
  abort: unknown revision 'e46a4836065c'!
  [255]
  $ sl id -ir b4594d867745
  abort: unknown revision 'b4594d867745'!
  [255]
  $ sl debugstrip -B singlenode1 -B singlenode2
  bookmark 'singlenode1' deleted
  bookmark 'singlenode2' deleted
  $ sl id -ir 43227190fef8
  abort: unknown revision '43227190fef8'!
  [255]
  $ sl debugstrip -B unknownbookmark
  abort: bookmark not found: 'unknownbookmark'
  [255]
  $ sl debugstrip -B unknownbookmark1 -B unknownbookmark2
  abort: bookmark not found: 'unknownbookmark1', 'unknownbookmark2'
  [255]
  $ sl debugstrip -B delete -B unknownbookmark
  abort: bookmark not found: 'unknownbookmark'
  [255]
  $ sl debugstrip -B delete
  bookmark 'delete' deleted
  $ sl id -ir 'desc(r10)':2702dd0c91e7
  abort: unknown revision '2702dd0c91e7'!
  [255]
  $ sl goto B
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark B)
  $ echo a > a
  $ sl add a
  $ sl debugstrip -B B
  abort: local changes found
  [255]
  $ sl bookmarks
   * B                         bde800a4ddec

Make sure no one adds back a -b option:

  $ sl debugstrip -b tip
  sl debugstrip: option -b not recognized
  (use 'sl debugstrip -h' to get help)
  [255]

  $ cd ..

Verify bundles don't get overwritten:

  $ sl init doublebundle
  $ cd doublebundle
  $ touch a
  $ sl commit -Aqm a
  $ touch b
  $ sl commit -Aqm b
  $ sl debugstrip -r 'desc(a)'
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ ls .sl/strip-backup
  3903775176ed-e68910bd-backup.hg
  $ sl unbundle -q .sl/strip-backup/3903775176ed-e68910bd-backup.hg
  $ sl debugstrip -r 'desc(a)'
  $ ls .sl/strip-backup
  3903775176ed-e68910bd-backup.hg
  $ cd ..

Test that we only bundle the stripped changesets (issue4736)
------------------------------------------------------------

initialization (previous repo is empty anyway)

  $ sl init issue4736
  $ cd issue4736
  $ echo a > a
  $ sl add a
  $ sl commit -m commitA
  $ echo b > b
  $ sl add b
  $ sl commit -m commitB
  $ echo c > c
  $ sl add c
  $ sl commit -m commitC
  $ sl up 'desc(commitB)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo d > d
  $ sl add d
  $ sl commit -m commitD
  $ sl up 'desc(commitC)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl merge 'desc(commitD)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m 'mergeCD'
  $ sl log -G
  @    commit:      d8db9d137221
  ├─╮  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  summary:     mergeCD
  │ │
  │ o  commit:      6625a5168474
  │ │  user:        test
  │ │  date:        Thu Jan 01 00:00:00 1970 +0000
  │ │  summary:     commitD
  │ │
  o │  commit:      5c51d8d6557d
  ├─╯  user:        test
  │    date:        Thu Jan 01 00:00:00 1970 +0000
  │    summary:     commitC
  │
  o  commit:      eca11cf91c71
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     commitB
  │
  o  commit:      105141ef12d0
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     commitA
  

Check bundle behavior:

  $ sl bundle -r 'desc(mergeCD)' --base 'desc(commitC)' ../issue4736.hg
  2 changesets found
  $ sl log -r 'bundle()' -R ../issue4736.hg
  commit:      6625a5168474
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commitD
  
  commit:      d8db9d137221
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     mergeCD
  

check strip behavior
(commitC is incorrectly included because the "_bundle" logic uses the
"outgoing" discovery logic to figure out what to bundle. The outgoing logic
cannot easily express revset like "commitD::", and it uses something like
"mergeCD % commitD". This should be fixed in the bundle / discovery logic,
unrelated to strip.)

  $ sl debugstrip 'desc(commitD)' --debug
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  3 changesets found
  list of changesets:
  5c51d8d6557d0cb2ed8ef7d1e19ea477fb90e327
  6625a516847449b6f0fa3737b9ba56e9f0f3032c
  d8db9d1372214336d2b5570f20ee468d2c72fa8b
  bundle2-output-bundle: "HG20", (1 params) 3 parts total
  bundle2-output-part: "changegroup" (params: 1 mandatory 1 advisory) streamed payload
  bundle2-output-part: "phase-heads" 24 bytes payload
  bundle2-output-part: "b2x:treegroup2" (params: 3 mandatory) streamed payload
  $ sl log -G
  o  commit:      5c51d8d6557d
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     commitC
  │
  @  commit:      eca11cf91c71
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     commitB
  │
  o  commit:      105141ef12d0
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     commitA
  

strip backup content

  $ sl log -r 'bundle()' -R .sl/strip-backup/6625a5168474-*-backup.hg
  commit:      5c51d8d6557d
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commitC
  
  commit:      6625a5168474
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commitD
  
  commit:      d8db9d137221
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     mergeCD
  
Check that the phase cache is properly invalidated after a strip with bookmark.

  $ cat > ../stripstalephasecache.py << EOF
  > from sapling import extensions, localrepo
  > def transactioncallback(orig, repo, desc, *args, **kwargs):
  >     def test(transaction):
  >         # observe cache inconsistency
  >         try:
  >             [repo.changelog.node(r) for r in repo.revs("not public()")]
  >         except IndexError:
  >             repo.ui.status("Index error!\n")
  >     transaction = orig(repo, desc, *args, **kwargs)
  >     # warm up the phase cache
  >     list(repo.revs("not public()"))
  >     if desc != 'strip':
  >          transaction.addpostclose("phase invalidation test", test)
  >     return transaction
  > def extsetup(ui):
  >     extensions.wrapfunction(localrepo.localrepository, "transaction",
  >                             transactioncallback)
  > EOF
  $ sl up -C 'desc(commitC)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo k > k
  $ sl add k
  $ sl commit -m commitK
  $ echo l > l
  $ sl add l
  $ sl commit -m commitL
  $ sl book -r tip blah
  $ sl debugstrip ".^" --config extensions.crash=$TESTTMP/stripstalephasecache.py
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl up -C 'desc(commitB)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

Use delayedstrip to strip inside a transaction

  $ cd $TESTTMP
  $ sl init delayedstrip
  $ cd delayedstrip
  $ sl debugdrawdag <<'EOS'
  >   D
  >   |
  >   C F H    # Commit on top of "I",
  >   | |/|    # Strip B+D+I+E+G+H+Z
  > I B E G
  >  \|/
  >   A   Z
  > EOS
  $ cp -R . ../scmutilcleanup

  $ sl up -C I
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark I)
  $ echo 3 >> I
  $ cat > $TESTTMP/delayedstrip.py <<EOF
  > from __future__ import absolute_import
  > from sapling import commands, registrar, repair
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command('testdelayedstrip')
  > def testdelayedstrip(ui, repo):
  >     def getnodes(expr):
  >         return [repo.changelog.node(r) for r in repo.revs(expr)]
  >     with repo.wlock():
  >         with repo.lock():
  >             with repo.transaction('delayedstrip'):
  >                 repair.delayedstrip(ui, repo, getnodes('B+I+Z+D+E'), 'J')
  >                 repair.delayedstrip(ui, repo, getnodes('G+H+Z'), 'I')
  >                 commands.commit(ui, repo, message='J', date='0 0')
  > EOF
  $ sl testdelayedstrip --config extensions.t=$TESTTMP/delayedstrip.py
  warning: orphaned descendants detected, not stripping 08ebfeb61bac, 112478962961, 7fb047a69f22

  $ sl log -G -T '{node|short} {desc}' -r 'sort(all(), topo)'
  @  2f2d51af6205 J
  │
  o  08ebfeb61bac I
  │
  │ o  64a8289d2492 F
  │ │
  │ o  7fb047a69f22 E
  ├─╯
  │ o  26805aba1e60 C
  │ │
  │ o  112478962961 B
  ├─╯
  o  426bada5c675 A
  
Test high-level scmutil.cleanupnodes API

  $ cd $TESTTMP/scmutilcleanup
  $ sl debugdrawdag <<'EOS'
  >   D2  F2  G2   # D2, F2, G2 are replacements for D, F, G
  >   |   |   |
  >   C   H   G
  > EOS
  $ for i in B C D F G I Z; do
  >     sl bookmark -i -r $i b-$i
  > done
  $ sl bookmark -i -r E 'b-F@divergent1'
  $ sl bookmark -i -r H 'b-F@divergent2'
  $ sl bookmark -i -r G 'b-F@divergent3'
  $ cp -R . ../scmutilcleanup.obsstore

  $ cat > $TESTTMP/scmutilcleanup.py <<EOF
  > from sapling import registrar, scmutil
  > cmdtable = {}
  > command = registrar.command(cmdtable)
  > @command('testnodescleanup')
  > def testnodescleanup(ui, repo):
  >     def nodes(expr):
  >         return [repo.changelog.node(r) for r in repo.revs(expr)]
  >     def node(expr):
  >         return nodes(expr)[0]
  >     with repo.wlock():
  >         with repo.lock():
  >             with repo.transaction('delayedstrip'):
  >                 mapping = {node('F'): [node('F2')],
  >                            node('D'): [node('D2')],
  >                            node('G'): [node('G2')]}
  >                 scmutil.cleanupnodes(repo, mapping, 'replace')
  >                 scmutil.cleanupnodes(repo, nodes('((B::)+I+Z)-D2'), 'replace')
  > EOF
  $ sl testnodescleanup --config extensions.t=$TESTTMP/scmutilcleanup.py

  $ sl log -G -T '{node|short} {desc} {bookmarks}' -r 'sort(all(), topo)'
  o  d11b3456a873 F2 F F2 b-F
  │
  o    5cb05ba470a7 H H
  ├─╮
  │ │ o  1473d4b996d1 G2 G G2 b-F@divergent3 b-G
  ├───╯
  o │  1fc8102cda62 G
    │
    o  7fb047a69f22 E E b-F@divergent1
    │
  o │  7c78f703e465 D2 D D2 b-D
  │ │
  o │  26805aba1e60 C
  │ │
  o │  112478962961 B
  ├─╯
  o  426bada5c675 A A B C I b-B b-C b-I
  $ sl bookmark
     A                         426bada5c675
     B                         426bada5c675
     C                         426bada5c675
     D                         7c78f703e465
     D2                        7c78f703e465
     E                         7fb047a69f22
     F                         d11b3456a873
     F2                        d11b3456a873
     G                         1473d4b996d1
     G2                        1473d4b996d1
     H                         5cb05ba470a7
     I                         426bada5c675
     Z                         000000000000
     b-B                       426bada5c675
     b-C                       426bada5c675
     b-D                       7c78f703e465
     b-F                       d11b3456a873
     b-F@divergent1            7fb047a69f22
     b-F@divergent3            1473d4b996d1
     b-G                       1473d4b996d1
     b-I                       426bada5c675
     b-Z                       000000000000

