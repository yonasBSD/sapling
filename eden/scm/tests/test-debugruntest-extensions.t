
#require no-eden


  $ export HGIDENTITY=sl
  $ cat > ex1.py <<EOS
  > from sapling import commands, extensions
  > def uisetup(ui):
  >     def files(orig, ui, *args, **kwargs):
  >         ui.status("ex1\n")
  >         return orig(ui, *args, **kwargs)
  >     extensions.wrapcommand(commands.table, "files", files)
  > EOS

  $ cat > ex2.py <<EOS
  > from sapling import commands, extensions
  > def uisetup(ui):
  >     def files(orig, ui, *args, **kwargs):
  >         ui.status("ex2\n")
  >         return orig(ui, *args, **kwargs)
  >     extensions.wrapcommand(commands.table, "files", files)
  > EOS

  $ newrepo
  $ echo foo > foo
  $ sl ci -Aqm foo
  $ sl files
  foo

  $ sl files --config extensions.ex1=~/ex1.py
  ex1
  foo

  $ sl files --config extensions.ex2=~/ex2.py
  ex2
  foo

  $ sl files --config extensions.ex2=~/ex2.py --config extensions.ex1=~/ex1.py
  ex2
  ex1
  foo

  $ sl files
  foo
