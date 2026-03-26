
#require no-eden


Do not use usernames from env vars:

  $ export HGIDENTITY=sl
  $ unset HGUSER EMAIL
  $ export HGRCPATH=sys=$HGRCPATH:user=$HOME/.config/sapling/sapling.conf

Without auto username:

  $ newrepo
  $ sl commit --config ui.allowemptycommit=1 -m 1
  abort: no username supplied
  (use `sl config --user ui.username "First Last <me@example.com>"` to set your username)
  [255]

With auto username:

  $ cat > $TESTTMP/a.py << 'EOF'
  > from sapling import extensions, ui as uimod
  > def auto_username(orig, ui):
  >     return "A B <c@d.com>"
  > def uisetup(ui):
  >     extensions.wrapfunction(uimod, '_auto_username', auto_username)
  > EOF

  $ setconfig extensions.a=$TESTTMP/a.py

  $ sl commit --config ui.allowemptycommit=1 -m 1

  $ sl log -r . -T '{author}\n'
  A B <c@d.com>

The username is saved in config file:

  $ sl config ui.username
  A B <c@d.com>
