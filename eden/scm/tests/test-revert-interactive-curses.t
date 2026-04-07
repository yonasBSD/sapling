#require tic no-eden

  $ eagerepo
Revert interactive tests with the Curses interface

  $ cat <<EOF >> $HGRCPATH
  > [ui]
  > interactive = true
  > interface = curses
  > [experimental]
  > crecordtest = testModeCommands
  > EOF

When a line without EOL is selected during "revert -i"

  $ sl init $TESTTMP/revert-i-curses-eol
  $ cd $TESTTMP/revert-i-curses-eol
  $ echo 0 > a
  $ sl ci -qAm 0
  $ echo -n 1 >> a
  $ cat a
  0
  1 (no-eol)

  $ cat <<EOF >testModeCommands
  > c
  > EOF

  $ sl revert -i a
  $ cat a
  0

When a selected line is reverted to have no EOL

  $ sl init $TESTTMP/revert-i-curses-eol2
  $ cd $TESTTMP/revert-i-curses-eol2
  $ echo -n boo > a
  $ sl ci -qAm 0
  $ echo blah > a

  $ cat <<EOF >testModeCommands
  > c
  > EOF

  $ sl revert -i a
  $ cat a
  boo (no-eol)
