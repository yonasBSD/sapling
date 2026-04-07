
#require no-eden



  $ sl init repo
  $ cd repo

no bookmarks

  $ sl bookmarks
  no bookmarks set

set bookmark X

  $ sl bookmark X

list bookmarks

  $ sl bookmark
   * X                         000000000000

list bookmarks with color

  $ sl --config extensions.color= --config color.mode=ansi \
  >     bookmark --color=always
  \x1b[32m * \x1b[39m\x1b[32mX\x1b[39m\x1b[32m                         000000000000\x1b[39m (esc)

update to bookmark X

  $ sl bookmarks
   * X                         000000000000
  $ sl goto X
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

list bookmarks

  $ sl bookmarks
   * X                         000000000000

rename

  $ sl bookmark -m X Z

list bookmarks

  $ sl bookmarks
   * Z                         000000000000

new bookmarks X and Y, first one made active

  $ sl bookmark Y X

list bookmarks

  $ sl bookmark
     X                         000000000000
   * Y                         000000000000
     Z                         000000000000

  $ sl bookmark -d X

commit

  $ echo 'b' > b
  $ sl add b
  $ sl commit -m'test'

list bookmarks

  $ sl bookmark
   * Y                         719295282060
     Z                         000000000000

Verify that switching to Z updates the active bookmark:
  $ sl goto Z
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (changing active bookmark from Y to Z)
  $ sl bookmark
     Y                         719295282060
   * Z                         000000000000

Switch back to Y for the remaining tests in this file:
  $ sl goto Y
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (changing active bookmark from Z to Y)

delete bookmarks

  $ sl bookmark -d Y
  $ sl bookmark -d Z

list bookmarks

  $ sl bookmark
  no bookmarks set

update to tip

  $ sl goto tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

set bookmark Y using -r . but make sure that the active
bookmark is not activated

  $ sl bookmark -r . Y

list bookmarks, Y should not be active

  $ sl bookmark
     Y                         719295282060

now, activate Y

  $ sl up -q Y

set bookmark Z using -i

  $ sl bookmark -r . -i Z
  $ sl bookmarks
   * Y                         719295282060
     Z                         719295282060

deactivate active bookmark using -i

  $ sl bookmark -i Y
  $ sl bookmarks
     Y                         719295282060
     Z                         719295282060

  $ sl up -q Y
  $ sl bookmark -i
  $ sl bookmarks
     Y                         719295282060
     Z                         719295282060
  $ sl bookmark -i
  no active bookmark
  $ sl up -q Y
  $ sl bookmarks
   * Y                         719295282060
     Z                         719295282060

deactivate active bookmark while renaming

  $ sl bookmark -i -m Y X
  $ sl bookmarks
     X                         719295282060
     Z                         719295282060

  $ echo a > a
  $ sl ci -Am1
  adding a
  $ echo b >> a
  $ sl ci -Am2
  $ sl goto -q X

test deleting .sl/bookmarks.current when explicitly updating
to a revision

  $ echo a >> b
  $ sl ci -m.
  $ sl up -q X
  $ test -f .sl/bookmarks.current

try to update to it again to make sure we don't
set and then unset it

  $ sl up -q X
  $ test -f .sl/bookmarks.current

  $ sl up -q 'desc(1)'
  $ test -f .sl/bookmarks.current
  [1]

when a bookmark is active, sl up -r . is
analogous to sl book -i <active bookmark>

  $ sl up -q X
  $ sl up -q .
  $ test -f .sl/bookmarks.current
  [1]

issue 4552 -- simulate a pull moving the active bookmark

  $ sl up -q X
  $ printf "Z" > .sl/bookmarks.current
  $ sl log -T '{activebookmark}\n' -r Z
  Z
  $ sl log -T '{bookmarks % "{active}\n"}' -r Z
  Z

