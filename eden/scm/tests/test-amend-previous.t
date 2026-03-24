
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo

Set up test environment.
  $ configure mutation-norecord
  $ enable amend rebase
  $ setconfig ui.disallowemptyupdate=true
  $ newrepo amendprevious

Check help text for new options and removal of unsupported options.
  $ sl previous --help
  sl previous [OPTIONS]... [STEPS]
  
  aliases: prev
  
  check out an ancestor commit
  
      Update to an ancestor commit of the current commit. When working with a
      stack of commits, you can use 'sl previous' to move down your stack with
      ease.
  
      - Use the "--newest" flag to always pick the newest of multiple parents
        commits. You can set "amend.alwaysnewest" to true in your global Sapling
        config file to make this the default.
      - Use the "--merge" flag to bring along uncommitted changes to the
        destination commit.
      - Use the "--bookmark" flag to move to the first ancestor commit with a
        bookmark.
  
      Examples:
  
      - Move 1 level down the stack:
  
          sl prev
  
      - Move 2 levels down the stack:
  
          sl prev 2
  
      - Move to the bottom of the stack:
  
          sl prev --bottom
  
  Options:
  
      --newest               always pick the newest parent when a commit has
                             multiple parents
      --bottom               update to the lowest non-public ancestor of the
                             current commit
      --bookmark             update to the first ancestor with a bookmark
      --no-activate-bookmark do not activate the bookmark on the destination
                             commit
   -C --clean                discard uncommitted changes (no backup)
   -B --move-bookmark        move active bookmark
   -m --merge                merge uncommitted changes
   -c --check                require clean working directory
  
  (some details hidden, use --verbose to show complete help)

Create stack of commits and go to the top.
  $ sl debugbuilddag --mergeable-file +6
  $ sl up tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl book top

Test invalid argument combinations.
  $ sl previous --bottom 1
  abort: cannot use both number and --bottom
  [255]
  $ sl previous --bookmark 1
  abort: cannot use both number and --bookmark
  [255]
  $ sl previous --bottom --bookmark
  abort: cannot use both --bottom and --bookmark
  [255]

Test basic usage.
  $ sl previous
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark top)
  [*] r4 (glob)

With positional argument.
  $ sl previous 2
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [*] r2 (glob)

Overshoot bottom of repo.
  $ sl previous 5
  reached root commit
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [*] r0 (glob)

Test --bottom flag.
  $ sl up top
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark top)
  $ sl previous --bottom
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark top)
  [*] r0 (glob)

Test bookmark navigation.
  $ sl book -r 'desc(r0)' root
  $ sl book -r 'desc(r2)' bookmark
  $ sl up top
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark top)
  $ sl previous --bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark top)
  [*] (bookmark) r2 (glob)
  (activating bookmark bookmark)
  $ sl previous --bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark bookmark)
  [*] (root) r0 (glob)
  (activating bookmark root)

Test bookmark activation.
  $ sl up top
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (changing active bookmark from root to top)
  $ sl previous 3
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark top)
  [*] (bookmark) r2 (glob)
  (activating bookmark bookmark)
  $ sl previous 2 --no-activate-bookmark
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark bookmark)
  [*] (root) r0 (glob)

Test dirty working copy and --merge.
  $ sl up top
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (activating bookmark top)
  $ echo "test" >> mf
  $ sl st
  M mf
  $ sl previous --check
  abort: uncommitted changes
  [255]
  $ sl previous --merge
  merging mf
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark top)
  [*] r4 (glob)
  $ sl st
  M mf

Test dirty working copy and --clean.
  $ sl previous --check
  abort: uncommitted changes
  [255]
  $ sl previous --clean
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [*] r3 (glob)
  $ sl st

Test multiple parents
  $ sl up 'desc(r3)' -q
  $ echo a > a && sl add a && sl commit -m a
  $ sl merge 'desc(r5)' -q && sl commit -m merge
  $ showgraph
  @    55f23eb33584 merge
  ├─╮
  │ o  8305126fd490 a
  │ │
  o │  f2987ebe5838 r5
  │ │
  o │  aa70f0fe546a r4
  ├─╯
  o  cb14eba0ad9c r3
  │
  o  f07e66f449d0 r2
  │
  o  09bb8c08de89 r1
  │
  o  fdaccbb26270 r0
  $ sl previous
  commit 55f23eb33584 has multiple parents, namely:
  [f2987e] (top) r5
  [830512] a
  abort: ambiguous previous commit
  (use the --newest flag to always pick the newest parent at each step)
  [255]
  $ sl --config ui.interactive=true previous 3 <<EOF
  > 1
  > EOF
  commit 55f23eb33584 has multiple parents, namely:
  (1) [f2987e] (top) r5
  (2) [830512] a
  which commit to select [1-2/(c)ancel]?  1
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  [cb14eb] r3
  $ sl up 'desc(merge)' -q
  $ sl --config ui.interactive=true previous 3 <<EOF
  > 2
  > EOF
  commit 55f23eb33584 has multiple parents, namely:
  (1) [f2987e] (top) r5
  (2) [830512] a
  which commit to select [1-2/(c)ancel]?  2
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  [f07e66] (bookmark) r2
  (activating bookmark bookmark)

Mix with bottom:
  $ sl debugmakepublic 'desc(r4)'
  $ sl up 'desc(merge)' -q
  $ sl prev --bottom
  current stack has multiple bottom commits, namely:
  [f2987e] (top) r5
  [830512] a
  abort: ambiguous bottom commit
  [255]
  $ sl --config ui.interactive=true previous --bottom <<EOF
  > 2
  > EOF
  current stack has multiple bottom commits, namely:
  (1) [f2987e] (top) r5
  (2) [830512] a
  which commit to select [1-2/(c)ancel]?  2
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [830512] a
