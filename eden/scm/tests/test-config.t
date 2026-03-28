
#require no-eden

hide outer repo
  $ export HGIDENTITY=sl
  $ sl init

Invalid syntax: no value

  $ cat > .sl/config << EOF
  > novaluekey
  > EOF
  $ sl config
  sl: parse errors: "*config": (glob)
  line 1: expect '[section]' or 'name = value'
  
  [255]

Invalid syntax: no key

  $ cat > .sl/config << EOF
  > =nokeyvalue
  > EOF
  $ sl config
  sl: parse errors: "*config": (glob)
  line 1: empty config name
  
  [255]

Invalid syntax: content after section

  $ cat > .sl/config << EOF
  > [section]#
  > EOF
  $ sl config
  sl: parse errors: "*config": (glob)
  line 1: extra content after section header
  
  [255]

Test hint about invalid syntax from leading white space

  $ cat > .sl/config << EOF
  >  key=value
  > EOF
  $ sl config
  sl: parse errors: "*config": (glob)
  line 1: indented line is not part of a multi-line config
  
  [255]

  $ cat > .sl/config << EOF
  >  [section]
  > key=value
  > EOF
  $ sl config
  sl: parse errors: "*config": (glob)
  line 1: indented line is not part of a multi-line config
  
  [255]

Reset hgrc

  $ echo > .sl/config

Test case sensitive configuration

  $ cat <<EOF >> $HGRCPATH
  > [Section]
  > KeY = Case Sensitive
  > key = lower case
  > EOF

  $ sl config Section
  Section.KeY=Case Sensitive
  Section.key=lower case

  $ sl config Section -Tjson
  [
  {
    "name": "Section.KeY",
    "source": "*", (glob)
    "value": "Case Sensitive"
  },
  {
    "name": "Section.key",
    "source": "*", (glob)
    "value": "lower case"
  }
  ]
  $ sl config Section.KeY -Tjson
  [
  {
    "name": "Section.KeY",
    "source": "*", (glob)
    "value": "Case Sensitive"
  }
  ]
  $ sl config -Tjson | tail -7
  },
  {
    "name": "*", (glob)
    "source": "*", (glob)
    "value": "*" (glob)
  }
  ]

Test "%unset"

  $ cat >> $HGRCPATH <<EOF
  > [unsettest]
  > local-hgrcpath = should be unset (HGRCPATH)
  > %unset local-hgrcpath
  > 
  > global = should be unset (HGRCPATH)
  > 
  > both = should be unset (HGRCPATH)
  > 
  > set-after-unset = should be unset (HGRCPATH)
  > EOF

  $ cat >> .sl/config <<EOF
  > [unsettest]
  > local-hgrc = should be unset (.sl/config)
  > %unset local-hgrc
  > 
  > %unset global
  > 
  > both = should be unset (.sl/config)
  > %unset both
  > 
  > set-after-unset = should be unset (.sl/config)
  > %unset set-after-unset
  > set-after-unset = should be set (.sl/config)
  > EOF

  $ sl config unsettest
  unsettest.set-after-unset=should be set (.sl/config)

  $ sl config unsettest.both
  [1]
  $ sl config unsettest.both --debug
  *: <%unset> (glob)

  $ sl config unsettest.both -Tjson
  [
  ]
  $ sl config unsettest.both -Tjson --debug
  [
  {
    "name": "unsettest.both",
    "source": "*", (glob)
    "value": null
  }
  ]

Read multiple values with -Tjson

  $ sl config --config=a.1=1 --config=a.2=2 --config=a.3=3 a.1 a.3 -Tjson
  [
  {
    "name": "a.1",
    "source": "--config",
    "value": "1"
  },
  {
    "name": "a.3",
    "source": "--config",
    "value": "3"
  }
  ]

  $ sl config --config=a.1=1 --config=a.2=2 --config=a.3=3 --config=b.1=4 --config=b.2=5 a.3 b a.1 -Tjson
  [
  {
    "name": "a.3",
    "source": "--config",
    "value": "3"
  },
  {
    "name": "b.1",
    "source": "--config",
    "value": "4"
  },
  {
    "name": "b.2",
    "source": "--config",
    "value": "5"
  },
  {
    "name": "a.1",
    "source": "--config",
    "value": "1"
  }
  ]

Config order is preserved:

  $ cat <<EOF >> $HGRCPATH
  > [ordertest]
  > a = 1
  > c = 3
  > b = 2
  > EOF

  $ sl config ordertest
  ordertest.a=1
  ordertest.c=3
  ordertest.b=2

Test exit code when no config matches

  $ sl config Section.idontexist
  [1]

sub-options in [paths] aren't expanded

  $ cat > .sl/config << EOF
  > [paths]
  > foo = ~/foo
  > foo:suboption = ~/foo
  > EOF

  $ sl config paths
  paths.foo=~/foo
  paths.foo:suboption=~/foo

edit failure

  $ HGEDITOR=false sl config --edit --quiet
  abort: edit failed: false exited with status 1
  [255]

  $ HGEDITOR=false sl config --user
  opening */sapling/sapling.conf for editing... (glob)
  abort: edit failed: false exited with status 1
  [255]

  $ sl config --user --local
  abort: please specify exactly one config location
  [255]

config affected by environment variables

  $ EDITOR=e1 sl config --debug | grep 'ui\.editor'
  $EDITOR: ui.editor=e1

  $ EDITOR=e2 sl config --debug --config ui.editor=e3 | grep 'ui\.editor'
  --config: ui.editor=e3

verify that aliases are evaluated as well

  $ sl init aliastest
  $ cd aliastest
  $ cat > .sl/config << EOF
  > [ui]
  > user = repo user
  > EOF
  $ touch index
  $ unset HGUSER
  $ sl ci -Am test
  adding index
  $ sl log --template '{author}\n'
  repo user
  $ cd ..

alias has lower priority

  $ sl init aliaspriority
  $ cd aliaspriority
  $ cat > .sl/config << EOF
  > [ui]
  > user = alias user
  > username = repo user
  > EOF
  $ touch index
  $ unset HGUSER
  $ sl ci -Am test
  adding index
  $ sl log --template '{author}\n'
  repo user
  $ cd ..

reponame is set from paths.default

  $ cat >> $HGRCPATH << EOF
  > [remotefilelog]
  > %unset reponame
  > EOF
  $ newrepo reponame-path-default-test
  $ sl paths --add default test:repo-myrepo1
  $ sl config remotefilelog.reponame
  repo-myrepo1
  $ cat .sl/reponame
  repo-myrepo1 (no-eol)

config editing without an editor

  $ newrepo

 invalid pattern
  $ sl config --edit missing.value
  abort: invalid config edit: 'missing.value'
  (try section.name=value)
  [255]

  $ sl config --edit missing=name
  abort: invalid config edit: 'missing'
  (try section.name=value)
  [255]

 append configs
  $ sl config --local aa.bb.cc.字 "配
  > 置" ee.fff=gggg
  updated config in $TESTTMP/*/.sl/config (glob)
  $ tail -6 .sl/config | dos2unix
  [aa]
  bb.cc.字 = 配
    置
  
  [ee]
  fff = gggg

 update config in-place without appending
  $ sl config --local aa.bb.cc.字 new_值 "aa.bb.cc.字=新值
  > 测
  > 试
  > "
  updated config in $TESTTMP/*/.sl/config (glob)
  $ tail -7 .sl/config | dos2unix
  [aa]
  bb.cc.字 = 新值
    测
    试
  
  [ee]
  fff = gggg

  $ sl config aa.bb.cc.字
  新值\n测\n试

 with comments
  $ newrepo
  $ cat > .sl/config << 'EOF'
  > [a]
  > # b = 1
  > b = 2
  >   second line
  > # b = 3
  > EOF

  $ sl config --local a.b 4
  updated config in $TESTTMP/*/.sl/config (glob)
  $ cat .sl/config
  [a]
  # b = 1
  b = 4
  # b = 3

  $ cd
  $ HGIDENTITY=sl newrepo
  $ sl config --local foo.bar baz
  updated config in $TESTTMP/*/.sl/config (glob)
  $ cat .sl/config | dos2unix
  # example repository config (see 'sl help config' for more info)
  [paths]
  # URL aliases to other repo sources
  # (see 'sl help config.paths' for more info)
  #
  # default = https://example.com/example-org/example-repo
  # my-fork = ssh://jdoe@example.com/jdoe/example-repo
  
  [ui]
  # name and email (local to this repository, optional), e.g.
  # username = Jane Doe <jdoe@example.com>
  
  [foo]
  bar = baz


 user config
  $ sl config --edit a.b=1 --quiet
  $ sl config a.b
  1

  $ sl config --user a.b 2
  updated config in $TESTTMP/*sapling* (glob)
  $ sl config a.b
  2

system config (make sure it tries the right file)
  $ HGEDITOR=false sl config --system
  opening $TESTTMP/config for editing...
  abort: edit failed: false exited with status 1
  [255]

Show builtin configs with --verbose (filtersuspectsymlink is merely a sample item from builtin:core):
  $ sl config | grep filtersuspectsymlink || true
  $ sl config --verbose | grep filtersuspectsymlink
  unsafe.filtersuspectsymlink=true

Warn about duplicate entries:
  $ newrepo
  $ cat > .sl/config << 'EOF'
  > [a]
  > b = 1
  > [a]
  > b = 2
  > EOF

  $ sl config --local a.b=3
  warning: duplicate config entries for a.b in $TESTTMP/*/.sl/config (glob)
  updated config in $TESTTMP/*/.sl/config (glob)
  $ cat .sl/config
  [a]
  b = 1
  [a]
  b = 3

Can see all sources w/ --debug and --verbose:
  $ newrepo sources
  $ cat > .sl/config << EOF
  > %include $TESTTMP/sources.rc
  > [foo]
  > bar = 1
  > [foo]
  > bar = 2
  > EOF

  $ cat > $TESTTMP/sources.rc << EOF
  > [foo]
  > bar = 3
  > EOF

  $ sl config foo.bar --debug --verbose
  $TESTTMP/sources/.sl/config:*: 2 (glob)
    $TESTTMP/sources/.sl/config:*: 1 (glob)
    $TESTTMP/sources.rc:*: 3 (glob)

  $ sl config foo --debug --verbose
  $TESTTMP/sources/.sl/config:*: foo.bar=2 (glob)
    $TESTTMP/sources/.sl/config:*: foo.bar=1 (glob)
    $TESTTMP/sources.rc:*: foo.bar=3 (glob)

Can delete in place:
  $ newrepo delete
  $ cat > .sl/config << EOF
  > [foo]
  > bar = 1
  > baz = 2
  > EOF

  $ sl config --delete foo.bar
  abort: --delete requires one of --user, --local or --system
  [255]

  $ sl config --delete --local foo.bar=123
  abort: invalid config deletion: 'foo.bar=123'
  (try section.name)
  [255]

  $ sl config --delete --local foo.bar -v
  deleting foo.bar from $TESTTMP/delete/.sl/config
  updated config in $TESTTMP/delete/.sl/config

  $ cat .sl/config
  [foo]
  baz = 2
