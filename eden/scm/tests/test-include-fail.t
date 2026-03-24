
#require execbit no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ cat >> $HGRCPATH <<EOF
  > [ui]
  > foo = bar
  > %include $TESTTMP/eperm/rc
  > EOF

  $ mkdir eperm
  $ cat > $TESTTMP/eperm/rc <<EOF
  > [ui]
  > foo = baz
  > EOF

  $ sl config ui.foo
  baz

An EPERM just causes the include to be ignored:

  $ chmod -x eperm
  $ sl config ui.foo
  bar
