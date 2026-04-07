
#require no-eden

#inprocess-hg-incompatible

  $ eagerepo
  $ configure mutation-norecord modernclient

Set up
  $ enable rebase tweakdefaults

  $ newclientrepo repo
  $ echo a > a
  $ sl commit -qAm aa
  $ sl bookmark one -i
  $ sl push -q -r . --to one --create
  $ echo b > b
  $ sl commit -qAm bb
  $ sl bookmark two -i
  $ sl push -q -r . --to two --create
  $ echo c > c
  $ sl commit -qAm cc
  $ sl bookmark three -i
  $ sl push -q -r . --to three --create
  $ newclientrepo clone repo_server one two three

Test that sl pull --rebase aborts without --dest
  $ sl log -G --all -T '{node|short} {bookmarks} {remotenames}'
  @  083f922fc4a9  remote/three
  │
  o  301d76bdc3ae  remote/two
  │
  o  8f0162e483d0  remote/one
  
  $ sl up -q remote/one
  $ touch foo
  $ sl commit -qAm 'foo'
  $ sl pull --rebase
  abort: missing rebase destination - supply --dest / -d
  [255]
  $ sl bookmark bm
  $ sl pull --rebase
  abort: missing rebase destination - supply --dest / -d
  [255]

  $ cp -R "$(sl root)" "$TESTTMP/repo-2"

Implicit rebase destination using tracking bookmark
  $ sl book bm -t remote/two
  $ sl pull --rebase
  pulling from test:repo_server
  rebasing 3de6bbccf693 "foo" (bm)
  $ sl pull --rebase --dest three
  pulling from test:repo_server
  rebasing 54ac787ff1c5 "foo" (bm)

Implicit rebase destination using main bookmark
  $ sl pull --rebase --config remotenames.selectivepulldefault=two --cwd "$TESTTMP/repo-2"
  pulling from test:repo_server
  rebasing 3de6bbccf693 "foo" (bm)


Test that sl pull --update aborts without --dest
  $ sl pull --update
  abort: you must specify a destination for the update
  (use `sl pull --update --dest <destination>`)
  [255]
  $ sl pull --update --dest one
  pulling from test:repo_server
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  (leaving bookmark bm)

Test that setting a defaultdest allows --update and --rebase to work
  $ sl pull --update --config tweakdefaults.defaultdest=two
  pulling from test:repo_server
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -G --all -T '{node|short} {bookmarks} {remotenames}'
  o  5413b62180b7 bm
  │
  o  083f922fc4a9  remote/three
  │
  @  301d76bdc3ae  remote/two
  │
  o  8f0162e483d0  remote/one
  
  $ echo d > d
  $ sl commit -qAm d
  $ sl pull --rebase --config tweakdefaults.defaultdest=three
  pulling from test:repo_server
  rebasing 50f3f60b4841 "d"
  $ sl log -G --all -T '{node|short} {bookmarks} {remotenames}'
  @  ba0f83735c95
  │
  │ o  5413b62180b7 bm
  ├─╯
  o  083f922fc4a9  remote/three
  │
  o  301d76bdc3ae  remote/two
  │
  o  8f0162e483d0  remote/one
  
Test that sl pull --rebase also works with a --tool argument
  $ echo d created at remote > ../repo/d
  $ sl -R ../repo update three -q
  $ sl -R ../repo commit -qAm 'remote d'
  $ sl -R ../repo push -r . -q --to three --create
  $ sl pull --rebase --dest three --tool internal:union
  pulling from test:repo_server
  searching for changes
  rebasing ba0f83735c95 "d"
  merging d
  $ sl log -G --all -T '{node|short} {bookmarks} {remotenames}'
  @  d6553cf01770
  │
  o  e8aa3bc9f3f0  remote/three
  │
  │ o  5413b62180b7 bm
  ├─╯
  o  083f922fc4a9
  │
  o  301d76bdc3ae  remote/two
  │
  o  8f0162e483d0  remote/one
  
  $ cat d
  d created at remote
  d
