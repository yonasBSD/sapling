
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo
Test the extensions.afterloaded() function

  $ cat > foo.py <<EOF
  > from sapling import extensions
  > def uisetup(ui):
  >     ui.write("foo.uisetup\\n")
  >     ui.flush()
  >     def bar_loaded(loaded):
  >         ui.write("foo: bar loaded: %r\\n" % (loaded,))
  >         ui.flush()
  >     extensions.afterloaded('bar', bar_loaded)
  > EOF
  $ cat > bar.py <<EOF
  > def uisetup(ui):
  >     ui.write("bar.uisetup\\n")
  >     ui.flush()
  > EOF
  $ basepath=`pwd`

  $ sl init basic
  $ cd basic
  $ echo foo > file
  $ sl add file
  $ sl commit -m 'add file'

  $ echo '[extensions]' >> .sl/config
  $ printf "%s\n" "foo = $basepath/foo.py" >> .sl/config
  $ printf "%s\n" "bar = $basepath/bar.py" >> .sl/config
  $ sl log -r. -T'{node}\n'
  foo.uisetup
  foo: bar loaded: True
  bar.uisetup
  c24b9ac61126c9cd86d5d684f8408cdc717005a4

Test afterloaded with the opposite extension load order

  $ cd ..
  $ sl init basic_reverse
  $ cd basic_reverse
  $ echo foo > file
  $ sl add file
  $ sl commit -m 'add file'

  $ echo '[extensions]' >> .sl/config
  $ printf "%s\n" "bar = $basepath/bar.py" >> .sl/config
  $ printf "%s\n" "foo = $basepath/foo.py" >> .sl/config
  $ sl log -r. -T'{node}\n'
  bar.uisetup
  foo.uisetup
  foo: bar loaded: True
  c24b9ac61126c9cd86d5d684f8408cdc717005a4

Test the extensions.afterloaded() function when the requested extension is not
loaded

  $ cd ..
  $ sl init notloaded
  $ cd notloaded
  $ echo foo > file
  $ sl add file
  $ sl commit -m 'add file'

  $ echo '[extensions]' >> .sl/config
  $ printf "%s\n" "foo = $basepath/foo.py" >> .sl/config
  $ sl log -r. -T'{node}\n'
  foo.uisetup
  foo: bar loaded: False
  c24b9ac61126c9cd86d5d684f8408cdc717005a4
