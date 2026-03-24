
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Test the flag to reuse another commit's message (-M):

  $ newrepo
  $ drawdag << 'EOS'
  > B
  > |
  > A
  > EOS
  $ sl up -Cq $B
  $ touch afile
  $ sl add afile
  $ sl commit -M $B
  $ tglog
  @  1c3d011e7c74 'B'
  │
  o  112478962961 'B'
  │
  o  426bada5c675 'A'
  
Ensure it's incompatible with other flags:
  $ echo 'canada rocks, eh?' > afile
  $ sl commit -M . -m 'this command will fail'
  abort: --reuse-message and --message are mutually exclusive
  [255]
  $ echo 'Super duper commit message' > ../commitmessagefile
  $ sl commit -M . -l ../commitmessagefile
  abort: --reuse-message and --logfile are mutually exclusive
  [255]
Ensure it supports nonexistant revisions:

  $ sl commit -M thisrevsetdoesnotexist
  abort: unknown revision 'thisrevsetdoesnotexist'!
  [255]

Ensure it populates the message editor:

  $ HGEDITOR=cat sl commit -M . -e
  B
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: changed afile
