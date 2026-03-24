
#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable commitextras
  $ newrepo
  $ echo data > file
  $ sl add file

Test commit message limit
  $ sl commit -m "long message" --config commit.description-size-limit=11
  abort: commit message length (12) exceeds configured limit (11)
  [255]
  $ sl commit -m "long message" --config commit.description-size-limit=12

  $ echo data >> file

Test extras limit
  $ sl commit -m "message" --extra "testextra=long value" \
  >   --config commit.extras-size-limit=18
  abort: commit extras total size (19) exceeds configured limit (18)
  [255]
  $ sl commit -m "message" --extra "testextra=long value" \
  >   --config commit.extras-size-limit=19
