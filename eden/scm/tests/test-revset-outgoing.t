#modern-config-incompatible

#require no-eden


  $ readconfig <<EOF
  > [alias]
  > tlog = log --template "{node|short}: '{desc}'\n"
  > EOF

  $ sl init a
  $ cd a

  $ echo a > a
  $ sl ci -Aqm0

  $ echo foo >> a
  $ sl ci -Aqm1

  $ sl up -q 'desc(0)'

  $ echo bar >> a
  $ sl ci -qm2

  $ tglog
  @  a578af2cfd0c '2'
  │
  │ o  3560197d8331 '1'
  ├─╯
  o  f7b1eb17ad24 '0'
  

  $ cd ..

  $ sl clone -q a b

  $ cd b
  $ cat .sl/config
  # example repository config (see 'sl help config' for more info)
  [paths]
  default = $TESTTMP/a
  
  # URL aliases to other repo sources
  # (see 'sl help config.paths' for more info)
  #
  # my-fork = https://example.com/jdoe/example-repo
  
  [ui]
  # name and email (local to this repository, optional), e.g.
  # username = Jane Doe <jdoe@example.com>

  $ echo red >> a
  $ sl ci -qm3

  $ sl up -q default

  $ echo blue >> a
  $ sl ci -qm4

  $ sl pull -q -r 3560197d8331

  $ tglog
  @  acadbdc73b28 '4'
  │
  o  5de9cb7d8f67 '3'
  │
  o  a578af2cfd0c '2'
  │
  │ o  3560197d8331 '1'
  ├─╯
  o  f7b1eb17ad24 '0'
  

  $ sl tlog -r 'outgoing()'
  5de9cb7d8f67: '3'
  acadbdc73b28: '4'

  $ sl tlog -r 'outgoing("../a")'
  5de9cb7d8f67: '3'
  acadbdc73b28: '4'

  $ echo "green = ../a" >> .sl/config

  $ cat .sl/config
  # example repository config (see 'sl help config' for more info)
  [paths]
  default = $TESTTMP/a
  
  # URL aliases to other repo sources
  # (see 'sl help config.paths' for more info)
  #
  # my-fork = https://example.com/jdoe/example-repo
  
  [ui]
  # name and email (local to this repository, optional), e.g.
  # username = Jane Doe <jdoe@example.com>
  green = ../a

  $ sl tlog -r 'outgoing("green")'
  abort: repository green does not exist!
  [255]

  $ cd ..
