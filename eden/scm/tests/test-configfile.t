
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ mkdir repo
  $ cd repo
  $ sl init
  $ export PROGRAMDATA="C:\\ProgramData\\Facebook\\Mercurial\\"
  $ export APPDATA="$TESTTMP\\AppData\\Roaming\\"

Test errors
  $ sl configfile --user --local
  abort: must select at most one of --user, --local, or --system
  [255]
  $ sl --cwd ../ configfile --local
  abort: --local must be used inside a repo
  [255]

Test locating user config
  $ sl configfile
  User config path: $TESTTMP/.config/sapling/sapling.conf (linux !)
  User config path: $TESTTMP/Library/Preferences/sapling/sapling.conf (osx !)
  Repo config path: $TESTTMP/repo/.sl/config
  System config path: $TESTTMP/hgrc
  $ sl configfile --user
  $TESTTMP/.config/sapling/sapling.conf (linux !)
  $TESTTMP/Library/Preferences/sapling/sapling.conf (osx !)
  $TESTTMP\AppData\Roaming\sapling\sapling.conf (windows !)

Test locating other configs
  $ sl configfile --local
  $TESTTMP/repo/.sl/config
  $ sl configfile --system
  $TESTTMP/hgrc

Test outside a repo
  $ cd
  $ sl configfile
  User config path: $TESTTMP/.config/sapling/sapling.conf (linux !)
  User config path: $TESTTMP/Library/Preferences/sapling/sapling.conf (osx !)
  System config path: $TESTTMP/hgrc
