
#require no-eden

  $ eagerepo
  $ newrepo

  $ echo 1 > foo
  $ echo 2 > bar
  $ sl add . -q

Commit should fail if the number of changed files exceeds the limit
  $ sl commit -m init --config commit.file-count-limit=1
  abort: commit file count (2) exceeds configured limit (1)
  (use '--config commit.file-count-limit=N' cautiously to override)
  [255]

Commit should succeed if the number of changed files <= the limit
  $ sl commit -m init --config commit.file-count-limit=2
  $ sl log -G -T '{desc}'
  @  init
