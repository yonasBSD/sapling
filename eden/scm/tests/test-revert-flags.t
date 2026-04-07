
#require execbit no-eden

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo foo > foo
  $ chmod 644 foo
  $ sl ci -qAm '644'

  $ chmod 755 foo
  $ sl ci -qAm '755'

reverting to rev 0

  $ sl revert -a -r 'desc(644)'
  reverting foo
  $ sl st
  M foo
  $ sl diff --git
  diff --git a/foo b/foo
  old mode 100755
  new mode 100644

  $ cd ..
