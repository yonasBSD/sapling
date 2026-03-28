
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo

  $ configure mutation-norecord
  $ enable morestatus fbhistedit histedit rebase reset
  $ setconfig morestatus.show=true
  $ cat >> $TESTTMP/breakupdate.py << EOF
  > import sys
  > from sapling import merge
  > def extsetup(ui):
  >     merge.applyupdates = lambda *args, **kwargs: sys.exit()
  > EOF
  $ breakupdate() {
  >   setconfig extensions.breakupdate="$TESTTMP/breakupdate.py"
  >   setconfig checkout.use-rust=false
  > }
  $ unbreakupdate() {
  >   disable breakupdate
  >   setconfig checkout.use-rust=true
  > }

Test An empty repo should return no extra output
  $ newclientrepo
  $ sl status

Test status on histedit stop
  $ echo 'a' > a
  $ sl commit -Am 'a' -q
  $ sl histedit -q --commands - . 2> /dev/null << EOF
  > stop cb9a9f314b8b a
  > EOF
  [1]
  $ sl status
  
  # The repository is in an unfinished *histedit* state.
  # To continue:                sl histedit --continue
  # To abort:                   sl histedit --abort


Test disabling output. Nothing should be shown
  $ sl status --config morestatus.show=False
  $ HGPLAIN=1 sl status
  $ sl histedit -q --continue

Test no output on normal state
  $ sl status

Test bisect state
  $ sl bisect --good
  $ sl status
  
  # The repository is in an unfinished *bisect* state.
  # Current bisect state: 1 good commit(s), 0 bad commit(s), 0 skip commit(s)
  # To mark the commit good:     sl bisect --good
  # To mark the commit bad:      sl bisect --bad
  # To abort:                    sl bisect --reset


Verify that suppressing a morestatus state warning works with the config knob:
  $ sl status --config morestatus.skipstates=bisect

Test sl status is normal after bisect reset
  $ sl bisect --reset
  $ sl status

Test graft state
  $ sl up -q -r 'max(desc(a))'
  $ echo '' > a
  $ sl commit -q -m 'remove content'

  $ sl up -q -r 'max(desc(a))'
  $ echo 'ab' > a
  $ sl commit -q -m 'add content'
  $ sl graft -q 2977a57
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  abort: unresolved conflicts, can't continue
  (use 'sl resolve' and 'sl graft --continue')
  [255]
  $ sl status
  M a
  ? a.orig
  
  # The repository is in an unfinished *graft* state.
  # Unresolved merge conflicts (1):
  # 
  #     a
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl graft --continue
  # To abort:                   sl graft --abort


Test sl status is normal after graft abort
  $ sl graft --abort -q
  $ sl up --clean -q .
  $ sl status
  ? a.orig
  $ rm a.orig

Test unshelve state
  $ enable shelve
  $ sl reset ".^" -q
  $ sl shelve -q
  $ sl up -r 2977a57 -q
  $ sl unshelve -q
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see 'sl resolve', then 'sl unshelve --continue')
  [1]

  $ sl status
  M a
  ? a.orig
  
  # The repository is in an unfinished *unshelve* state.
  # Unresolved merge conflicts (1):
  # 
  #     a
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl unshelve --continue
  # To abort:                   sl unshelve --abort


Test sl status is normal after unshelve abort
  $ sl unshelve --abort
  rebase aborted
  unshelve of 'default' aborted
  $ sl status
  ? a.orig
  $ rm a.orig

Test rebase state
  $ echo "rebase=" >> $HGRCPATH
  $ sl up -r 0efcea34f18aa8f87dc63b4c37b7c494bc778b03 -q
  $ echo 'ab' > a
  $ sl commit -q -m 'add content'
  $ sl rebase -s 2977a57 -d . -q
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl status
  M a
  ? a.orig
  
  # The repository is in an unfinished *rebase* state.
  # Unresolved merge conflicts (1):
  # 
  #     a
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl rebase --continue
  # To abort:                   sl rebase --abort
  # To quit:                    sl rebase --quit
  # 
  # Rebasing 2977a57ce863 (remove content)
  #       to 79361b8cdbb5 (add content)


Test status in rebase state with resolved files
  $ sl resolve --mark a
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl status
  M a
  ? a.orig
  
  # The repository is in an unfinished *rebase* state.
  # No unresolved merge conflicts.
  # To continue:                sl rebase --continue
  # To abort:                   sl rebase --abort
  # To quit:                    sl rebase --quit
  # 
  # Rebasing 2977a57ce863 (remove content)
  #       to 79361b8cdbb5 (add content)


Test sl status is normal after rebase abort
  $ sl rebase --abort -q
  rebase aborted
  $ sl status
  ? a.orig
  $ rm a.orig

Test rebase with an interrupted update:
  $ breakupdate
  $ sl rebase -s 2977a57ce863 -d 79361b8cdbb5 -q
  $ unbreakupdate
  $ sl status
  
  # The repository is in an unfinished *rebase* state.
  # To continue:                sl rebase --continue
  # To abort:                   sl rebase --abort
  # To quit:                    sl rebase --quit

  $ sl rebase --abort -q
  rebase aborted

Test conflicted merge state
  $ sl merge -q
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  [1]
  $ sl status
  M a
  ? a.orig
  
  # The repository is in an unfinished *merge* state.
  # Unresolved merge conflicts (1):
  # 
  #     a
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl commit
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)


Test if listed files have a relative path to current location
  $ mkdir -p b/c
  $ cd b/c
  $ sl status
  M ../../a
  ? ../../a.orig
  
  # The repository is in an unfinished *merge* state.
  # Unresolved merge conflicts (1):
  # 
  #     ../../a
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl commit
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)

  $ cd ../..

Test sl status is normal after merge abort
  $ sl goto --clean -q .
  $ sl status
  ? a.orig
  $ rm a.orig

Test non-conflicted merge state
  $ sl up -r 0efcea34f18aa8f87dc63b4c37b7c494bc778b03 -q
  $ touch z
  $ sl add z
  $ sl commit -m 'a commit that will merge without conflicts' -q
  $ sl merge -r 79361b8cdbb -q
  $ sl status
  M a
  
  # The repository is in an unfinished *merge* state.
  # To continue:                sl commit
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)


Test sl status is normal after merge commit (no output)
  $ sl commit -m 'merge commit' -q
  $ sl status

Test interrupted update state, without active bookmark and REV is a hash
  $ breakupdate
  $ sl goto -C 2977a57ce863
  $ sl status
  
  # The repository is in an unfinished *update* state.
  # To continue:                sl goto -C 2977a57ce863
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)


Test interrupted update state, with active bookmark and REV is a bookmark
  $ sl bookmark b1
  $ sl bookmark -r 79361b8cdbb5 b2
  $ sl goto b2
  $ sl status
  
  # The repository is in an unfinished *update* state.
  # To continue:                sl goto b2
  # To abort:                   sl goto b1 --clean    (warning: this will discard uncommitted changes)


Test update state can be reset using bookmark
  $ sl goto b1 -q
  $ sl bookmark -d b1 -q
  $ sl status

Test interrupted update state, without active bookmark and REV is specified using date
  $ echo a >> a
  $ sl commit --date "1234567890 0" -m m -q
  $ sl goto --date 1970-1-1 -q
  $ sl status
  
  # The repository is in an unfinished *update* state.
  # To continue:                sl goto --date 1970-1-1 -q
  # To abort:                   sl goto . --clean    (warning: this will discard uncommitted changes)


  $ unbreakupdate

Test update state can be reset using .
  $ sl goto . -q
  $ sl status

Test args escaping in continue command
  $ breakupdate
  $ sl bookmark b1
  $ sl --config extensions.fsmonitor=! --config ui.ssh="ssh -oControlMaster=no" update -C 2977a57ce863
  $ sl status
  
  # The repository is in an unfinished *update* state.
  # To continue:                sl --config 'extensions.fsmonitor=!' --config 'ui.ssh=ssh -oControlMaster=no' update -C 2977a57ce863
  # To abort:                   sl goto b1 --clean    (warning: this will discard uncommitted changes)


  $ unbreakupdate
  $ sl goto --clean b1
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl status

Test bisect search status (after cleaning up previous setup)
  $ echo 'z' > z
  $ sl commit -Am 'z' -q
  $ sl bisect --bad
  $ sl bisect --good 0efcea34f18a
  Testing changeset 69a19f24e505 (5 changesets remaining, ~2 tests)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl status
  
  # The repository is in an unfinished *bisect* state.
  # Current bisect state: 1 good commit(s), 1 bad commit(s), 0 skip commit(s)
  # 
  # Current Tracker: good commit    current        bad commit
  #                  0efcea34f18a...69a19f24e505...547e426ae373
  # Commits remaining:           5
  # Estimated bisects remaining: 3
  # To mark the commit good:     sl bisect --good
  # To mark the commit bad:      sl bisect --bad
  # To abort:                    sl bisect --reset


Test sl status is normal after bisect reset
  $ sl bisect --reset
  $ sl status
