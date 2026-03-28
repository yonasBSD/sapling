
#require no-eden

Use hgrc within $TESTTMP

  $ export HGIDENTITY=sl
  $ cp $HGRCPATH orig.hgrc
  $ HGRCPATH=`pwd`/config
  $ SL_CONFIG_PATH=`pwd`/config
  $ export HGRCPATH SL_CONFIG_PATH
  $ cp orig.hgrc config

Use an alternate var for scribbling on hgrc to keep check-code from
complaining about the important settings we may be overwriting:

  $ HGRC=`pwd`/config
  $ export HGRC

Basic syntax error

  $ echo "invalid" > $HGRC
  $ sl version
  sl: parse errors: "$TESTTMP*config": (glob)
  line 1: expect '[section]' or 'name = value'
  
  [255]
  $ cp orig.hgrc config

Issue1199: Can't use '%' in hgrc (eg url encoded username)

  $ newclientrepo "foo%bar"
  $ newclientrepo foobar foo%bar_server
  $ cat .sl/config
  [paths]
  default = test:foo%bar_server
  $ sl paths
  default = test:foo%EF%BF%BDr_server
  $ sl config paths
  paths.default=test:foo%bar_server
  $ cd ..

issue1829: wrong indentation

  $ echo '[foo]' > $HGRC
  $ echo '  x = y' >> $HGRC
  $ sl version
  sl: parse errors: "$TESTTMP*config": (glob)
  line 2: indented line is not part of a multi-line config
  
  [255]

  $ printf '[foo]\nbar = a\n b\n c \n  de\n fg \nbaz = bif cb \n' > $HGRC
  $ sl config foo
  foo.bar=a\nb\nc\nde\nfg
  foo.baz=bif cb

  $ cp $TESTTMP/orig.hgrc $HGRC
  $ FAKEPATH=/path/to/nowhere
  $ export FAKEPATH
  $ echo '%include $FAKEPATH/no-such-file' >> $HGRC
  $ sl version -q
  * (glob)
  $ unset FAKEPATH

make sure global options given on the cmdline take precedence

  $ sl config --config ui.verbose=True ui.verbose
  True
(fixme: 'ui.verbose' config is not effective with --quiet)
  $ sl config --config ui.verbose=True --quiet ui.verbose
  false
  $ sl config --verbose ui.verbose
  true
  $ sl config --quiet ui.quiet
  true
  $ sl config ui.quiet
  [1]

  $ touch foobar/untracked
  $ cat >> foobar/.sl/config <<EOF
  > [ui]
  > verbose=True
  > EOF
  $ sl -R foobar st -q

username expansion

  $ olduser=$HGUSER
  $ unset HGUSER

  $ FAKEUSER='John Doe'
  $ export FAKEUSER
  $ echo '[ui]' >> $HGRC
  $ echo 'username = $FAKEUSER' >> $HGRC

  $ newclientrepo usertest
  $ touch bar
  $ sl commit --addremove --quiet -m "added bar"
  $ sl log --template "{author}\n"
  John Doe
  $ cd ..

  $ sl config | grep ui.username
  ui.username=$FAKEUSER

  $ unset FAKEUSER
  $ HGUSER=$olduser
  $ export HGUSER

showconfig with multiple arguments

  $ echo "[alias]" > $HGRC
  $ echo "log = log -g" >> $HGRC
  $ echo "[defaults]" >> $HGRC
  $ echo "identify = -n" >> $HGRC
  $ sl config alias defaults
  alias.some-command=some-command --some-flag
  alias.log=log -g
  defaults.identify=-n
  $ sl config alias defaults.identify
  abort: only one config item permitted
  [255]
  $ sl config alias.log defaults.identify
  abort: only one config item permitted
  [255]

HGPLAIN

  $ echo "[ui]" > $HGRC
  $ echo "debug=true" >> $HGRC
  $ echo "fallbackencoding=ASCII" >> $HGRC
  $ echo "quiet=true" >> $HGRC
  $ echo "slash=true" >> $HGRC
  $ echo "traceback=true" >> $HGRC
  $ echo "verbose=true" >> $HGRC
  $ echo "style=~/.hgstyle" >> $HGRC
  $ echo "logtemplate={node}" >> $HGRC
  $ echo "[defaults]" >> $HGRC
  $ echo "identify=-n" >> $HGRC
  $ echo "[alias]" >> $HGRC
  $ echo "log=log -g" >> $HGRC

customized hgrc

  $ sl config
  $TESTTMP/config:13: alias.log=log -g
  $TESTTMP/config:11: defaults.identify=-n
  $TESTTMP/config:8: ui.style=~/.hgstyle
  $TESTTMP/config:2: ui.debug=true
  $TESTTMP/config:3: ui.fallbackencoding=ASCII
  $TESTTMP/config:4: ui.quiet=true
  $TESTTMP/config:5: ui.slash=true
  $TESTTMP/config:6: ui.traceback=true
  $TESTTMP/config:7: ui.verbose=true
  $TESTTMP/config:9: ui.logtemplate={node}

plain hgrc

  $ HGPLAIN=; export HGPLAIN
  $ sl config --config ui.traceback=True --debug
  --config: ui.traceback=True
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False

with environment variables

  $ PAGER=p1 EDITOR=e1 VISUAL=e2 sl config --debug
  $VISUAL: ui.editor=e2
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False

don't set editor to empty string

  $ VISUAL= sl config --debug
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False

plain mode with exceptions

  $ cat > plain.py <<EOF
  > from sapling import commands, extensions
  > def _config(orig, ui, repo, *values, **opts):
  >     ui.write('plain: %r\n' % ui.plain())
  >     return orig(ui, repo, *values, **opts)
  > def uisetup(ui):
  >     extensions.wrapcommand(commands.table, 'config', _config)
  > EOF
  $ echo "[extensions]" >> $HGRC
  $ echo "plain=./plain.py" >> $HGRC
  $ HGPLAINEXCEPT=; export HGPLAINEXCEPT
  $ sl config --config ui.traceback=True --debug
  plain: True
  $TESTTMP/config:15: extensions.plain=./plain.py
  --config: ui.traceback=True
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False
  $ unset HGPLAIN
  $ sl config --config ui.traceback=True --debug
  plain: True
  $TESTTMP/config:15: extensions.plain=./plain.py
  --config: ui.traceback=True
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False
  $ HGPLAINEXCEPT=i18n; export HGPLAINEXCEPT
  $ sl config --config ui.traceback=True --debug
  plain: True
  $TESTTMP/config:15: extensions.plain=./plain.py
  --config: ui.traceback=True
  --verbose: ui.verbose=False
  --debug: ui.debug=True
  --quiet: ui.quiet=False

source of paths is not mangled

  $ cat >> $HGRCPATH <<EOF
  > [paths]
  > foo = $TESTTMP/bar
  > EOF
  $ sl config --debug paths
  plain: True
  $TESTTMP/config:17: paths.foo=$TESTTMP/bar
