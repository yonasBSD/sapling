
#require no-eden

  $ enable rebase amend

  $ newrepo
  $ drawdag << 'EOS'
  > C   # C/A = (removed)
  > |
  > B
  > |
  > A
  > EOS

  $ sl up -q $C

--amend without --mark is unsupported (for now, alternative: regular cp + amend):

  $ sl cp --amend B C
  abort: --amend without --mark is not supported
  [255]

Mark 'C' as copied from 'B':

  $ sl cp B C
  C: not overwriting - file already committed
  (use 'sl copy --amend --mark' to amend the current commit)

  $ sl cp --amend --mark B C
  abort: 'B' and 'C' does not look similar
  (use --force to skip similarity check)
  [255]

  $ sl cp --amend --mark B C --force

Check result:

  $ sl status
  $ sl status --change . -AC C
  A C
    B

Change "C" to be renamed from "A":

  $ sl mv --amend --mark --mark A C
  abort: target path 'C' is already marked as copied from 'B'
  (use --force to skip this check)
  [255]

  $ sl mv --amend --mark A C --force

Check result:

  $ sl status
  $ sl status --change . -AC C
  A C
    A

Test behavior in middle of stack:
  $ newrepo
  $ drawdag <<EOS
  > C  # C/bar = bar
  > |
  > |
  > B  # B/bar = foo
  > |  # B/foo = (removed)
  > |
  > A  # A/foo = foo
  >    # drawdag.defaultfiles=false
  > EOS

  $ sl go -q $B
  $ tglog
  o  0dfdb4eecd4e 'C'
  │
  @  f9f49b656be4 'B'
  │
  o  84d740d4dbe5 'A'

Old B not obsoleted:
  $ sl mv --mark --amend foo bar
  $ tglog
  @  3354b93fbdbf 'B'
  │
  │ o  0dfdb4eecd4e 'C'
  │ │
  │ x  f9f49b656be4 'B'
  ├─╯
  o  84d740d4dbe5 'A'

Can restack:
  $ sl rebase -q --restack

  $ tglog
  o  1a2db52f05ac 'C'
  │
  @  3354b93fbdbf 'B'
  │
  o  84d740d4dbe5 'A'
