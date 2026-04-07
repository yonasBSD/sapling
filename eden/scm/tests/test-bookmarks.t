
#require no-eden

  $ newclientrepo repo

  $ cat > $TESTTMP/hook.sh <<'EOF'
  > echo "test-hook-bookmark: $HG_BOOKMARK:  $HG_OLDNODE -> $HG_NODE"
  > EOF
  $ TESTHOOK="hooks.txnclose-bookmark.test=sh $TESTTMP/hook.sh"

no bookmarks

  $ sl bookmarks
  no bookmarks set

  $ sl bookmarks -Tjson
  [
  ]

bookmark rev -1

  $ sl bookmark X --config "$TESTHOOK"
  test-hook-bookmark: X:   -> 0000000000000000000000000000000000000000

list bookmarks

  $ sl bookmarks
   * X                         000000000000

list bookmarks with color

  $ sl --config extensions.color= --config color.mode=ansi \
  >    bookmarks --color=always
  \x1b[32m * \x1b[39m\x1b[32mX\x1b[39m\x1b[32m                         000000000000\x1b[39m (esc)

  $ echo a > a
  $ sl add a
  $ sl commit -m 0 --config "$TESTHOOK"
  test-hook-bookmark: X:  0000000000000000000000000000000000000000 -> f7b1eb17ad24730a1651fccd46c43826d1bbc2ac

bookmark X moved to rev 0

  $ sl bookmarks
   * X                         f7b1eb17ad24

look up bookmark

  $ sl log -r X
  commit:      f7b1eb17ad24
  bookmark:    X
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  

second bookmark for rev 0, command should work even with ui.strict on

  $ sl --config ui.strict=1 bookmark X2 --config "$TESTHOOK"
  test-hook-bookmark: X2:   -> f7b1eb17ad24730a1651fccd46c43826d1bbc2ac

bookmark rev -1 again

  $ sl bookmark -r null Y

list bookmarks

  $ sl bookmarks
     X                         f7b1eb17ad24
   * X2                        f7b1eb17ad24
     Y                         000000000000

  $ echo b > b
  $ sl add b
  $ sl commit -m 1 --config "$TESTHOOK"
  test-hook-bookmark: X2:  f7b1eb17ad24730a1651fccd46c43826d1bbc2ac -> 925d80f479bb026b0fb3deb27503780b13f74123

  $ sl bookmarks -Tjson
  [
   {
    "active": false,
    "bookmark": "X",
    "node": "f7b1eb17ad24730a1651fccd46c43826d1bbc2ac"
   },
   {
    "active": true,
    "bookmark": "X2",
    "node": "925d80f479bb026b0fb3deb27503780b13f74123"
   },
   {
    "active": false,
    "bookmark": "Y",
    "node": "0000000000000000000000000000000000000000"
   }
  ]

bookmarks revset

  $ sl log -r 'bookmark()'
  commit:      f7b1eb17ad24
  bookmark:    X
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  
  commit:      925d80f479bb
  bookmark:    X2
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     1
  
  $ sl log -r 'bookmark(Y)'
  $ sl log -r 'bookmark(X2)'
  commit:      925d80f479bb
  bookmark:    X2
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     1
  
  $ sl log -r 'bookmark("re:X")'
  commit:      f7b1eb17ad24
  bookmark:    X
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  
  commit:      925d80f479bb
  bookmark:    X2
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     1
  
  $ sl log -r 'bookmark("literal:X")'
  commit:      f7b1eb17ad24
  bookmark:    X
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  

  $ sl log -r 'bookmark(unknown)'
  abort: bookmark 'unknown' does not exist!
  [255]
  $ sl log -r 'bookmark("literal:unknown")'
  abort: bookmark 'unknown' does not exist!
  [255]
  $ sl log -r 'bookmark("re:unknown")'
  abort: no bookmarks exist that match 'unknown'!
  [255]
  $ sl log -r 'present(bookmark("literal:unknown"))'
  $ sl log -r 'present(bookmark("re:unknown"))'

  $ sl help revsets | grep 'bookmark('
      "bookmark([name])"
      "remotebookmark([name])"

bookmarks X and X2 moved to rev 1, Y at rev -1

  $ sl bookmarks
     X                         f7b1eb17ad24
   * X2                        925d80f479bb
     Y                         000000000000

bookmark rev 0 again

  $ sl bookmark -r 'desc(0)' Z

  $ sl goto X
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (changing active bookmark from X2 to X)
  $ echo c > c
  $ sl add c
  $ sl commit -m 2

bookmarks X moved to rev 2, Y at rev -1, Z at rev 0

  $ sl bookmarks
   * X                         db815d6d32e6
     X2                        925d80f479bb
     Y                         000000000000
     Z                         f7b1eb17ad24

rename nonexistent bookmark

  $ sl bookmark -m A B
  abort: bookmark 'A' does not exist
  [255]

rename to existent bookmark

  $ sl bookmark -m X Y
  abort: bookmark 'Y' already exists (use -f to force)
  [255]

force rename to existent bookmark

  $ sl bookmark -f -m X Y

rename bookmark using .

  $ sl book rename-me
  $ sl book -m . renamed --config "$TESTHOOK"
  test-hook-bookmark: rename-me:  db815d6d32e69058eadefc8cffbad37675707975 -> 
  test-hook-bookmark: renamed:   -> db815d6d32e69058eadefc8cffbad37675707975
  $ sl bookmark
     X2                        925d80f479bb
     Y                         db815d6d32e6
     Z                         f7b1eb17ad24
   * renamed                   db815d6d32e6
  $ sl up -q Y
  $ sl book -d renamed --config "$TESTHOOK"
  test-hook-bookmark: renamed:  db815d6d32e69058eadefc8cffbad37675707975 -> 

rename bookmark using . with no active bookmark

  $ sl book rename-me
  $ sl book -i rename-me
  $ sl book -m . renamed
  abort: no active bookmark
  [255]
  $ sl up -q Y
  $ sl book -d rename-me

delete bookmark using .

  $ sl book delete-me
  $ sl book -d .
  $ sl bookmark
     X2                        925d80f479bb
     Y                         db815d6d32e6
     Z                         f7b1eb17ad24
  $ sl up -q Y

delete bookmark using . with no active bookmark

  $ sl book delete-me
  $ sl book -i delete-me
  $ sl book -d .
  abort: no active bookmark
  [255]
  $ sl up -q Y
  $ sl book -d delete-me

list bookmarks

  $ sl bookmark
     X2                        925d80f479bb
   * Y                         db815d6d32e6
     Z                         f7b1eb17ad24

bookmarks from a revset
  $ sl bookmark -r '.^1' REVSET
  $ sl bookmark -r ':tip' TIP
  $ sl up -q TIP
  $ sl bookmarks
     REVSET                    f7b1eb17ad24
   * TIP                       db815d6d32e6
     X2                        925d80f479bb
     Y                         db815d6d32e6
     Z                         f7b1eb17ad24

  $ sl bookmark -d REVSET
  $ sl bookmark -d TIP

rename without new name or multiple names

  $ sl bookmark -m Y
  abort: new bookmark name required
  [255]
  $ sl bookmark -m Y Y2 Y3
  abort: only one new bookmark name allowed
  [255]

delete without name

  $ sl bookmark -d
  abort: bookmark name required
  [255]

delete nonexistent bookmark

  $ sl bookmark -d A
  abort: bookmark 'A' does not exist
  [255]

ensure bookmark names are deduplicated before deleting
  $ sl book delete-me
  $ sl book -d delete-me delete-me

bookmark name with spaces should be stripped

  $ sl bookmark ' x  y '

list bookmarks

  $ sl bookmarks
     X2                        925d80f479bb
     Y                         db815d6d32e6
     Z                         f7b1eb17ad24
   * x  y                      db815d6d32e6

look up stripped bookmark name

  $ sl log -r '"x  y"'
  commit:      db815d6d32e6
  bookmark:    Y
  bookmark:    x  y
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     2
  

reject bookmark name with newline

  $ sl bookmark '
  > '
  abort: bookmark names cannot consist entirely of whitespace
  [255]

  $ sl bookmark -m Z '
  > '
  abort: bookmark names cannot consist entirely of whitespace
  [255]

bookmark with reserved name

  $ sl bookmark tip
  abort: the name 'tip' is reserved
  [255]

  $ sl bookmark .
  abort: the name '.' is reserved
  [255]

  $ sl bookmark null
  abort: the name 'null' is reserved
  [255]


bookmark with existing name

  $ sl bookmark X2
  abort: bookmark 'X2' already exists (use -f to force)
  [255]

  $ sl bookmark -m Y Z
  abort: bookmark 'Z' already exists (use -f to force)
  [255]

bookmark with name of branch (allowed - branches are deprecated)

  $ sl bookmark default
  $ sl bookmark -f default
  $ sl book -d default

  $ sl bookmark -f -m Y default
  $ sl book -m default Y

bookmark with integer name

  $ sl bookmark 10
  abort: cannot use an integer as a name
  [255]

bookmark with a name that matches a node id
  $ sl bookmark 925d80f479bb db815d6d32e6 --config "$TESTHOOK"
  bookmark 925d80f479bb matches a changeset hash
  (did you leave a -r out of an 'sl bookmark' command?)
  bookmark db815d6d32e6 matches a changeset hash
  (did you leave a -r out of an 'sl bookmark' command?)
  test-hook-bookmark: 925d80f479bb:   -> db815d6d32e69058eadefc8cffbad37675707975
  test-hook-bookmark: db815d6d32e6:   -> db815d6d32e69058eadefc8cffbad37675707975
  $ sl bookmark -d 925d80f479bb
  $ sl bookmark -d db815d6d32e6
Don't warn if name clearly isn't a hex node.
  $ sl push --to remote-bookmark-name --create -q
  $ sl bookmark remote-bookmark-name
  $ sl book -d remote-bookmark-name

  $ cd ..

incompatible options

  $ cd repo

  $ sl bookmark -m Y -d Z
  abort: --delete and --rename are incompatible
  [255]

  $ sl bookmark -r 'desc(1)' -d Z
  abort: --rev is incompatible with --delete
  [255]

  $ sl bookmark -r 'desc(1)' -m Z Y
  abort: --rev is incompatible with --rename
  [255]

force bookmark with existing name

  $ sl bookmark -f X2 --config "$TESTHOOK"
  test-hook-bookmark: X2:  925d80f479bb026b0fb3deb27503780b13f74123 -> db815d6d32e69058eadefc8cffbad37675707975

force bookmark back to where it was, should deactivate it

  $ sl bookmark -fr'desc(1)' X2
  $ sl bookmarks
     X2                        925d80f479bb
     Y                         db815d6d32e6
     Z                         f7b1eb17ad24
     x  y                      db815d6d32e6

forward bookmark to descendant without --force

  $ sl bookmark Z
  moving bookmark 'Z' forward from f7b1eb17ad24

list bookmarks

  $ sl bookmark
     X2                        925d80f479bb
     Y                         db815d6d32e6
   * Z                         db815d6d32e6
     x  y                      db815d6d32e6

bookmark name with whitespace only

  $ sl bookmark ' '
  abort: bookmark names cannot consist entirely of whitespace
  [255]

  $ sl bookmark -m Y ' '
  abort: bookmark names cannot consist entirely of whitespace
  [255]

invalid bookmark

  $ sl bookmark 'foo:bar'
  abort: ':' cannot be used in a name
  [255]

  $ sl bookmark 'foo
  > bar'
  abort: '\n' cannot be used in a name
  [255]

the bookmark extension should be ignored now that it is part of core

  $ echo "[extensions]" >> $HGRCPATH
  $ echo "bookmarks=" >> $HGRCPATH
  $ sl bookmarks
     X2                        925d80f479bb
     Y                         db815d6d32e6
   * Z                         db815d6d32e6
     x  y                      db815d6d32e6

test summary

  $ sl summary
  parent: db815d6d32e6 
   2
  bookmarks: *Z Y x  y
  commit: (clean)
  phases: 3 draft

test id

  $ sl id
  db815d6d32e6 Y/Z/x  y

  $ echo foo > f1

activate bookmark on working dir parent without --force

  $ sl bookmark --inactive Z
  $ sl bookmark Z

test clone

  $ sl bookmark -r 'desc(2)' -i @
  $ sl bookmark -r 'desc(2)' -i a@

delete multiple bookmarks at once

  $ sl bookmark -d @ a@

