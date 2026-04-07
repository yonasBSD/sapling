#modern-config-incompatible

#require no-eden

#inprocess-hg-incompatible
  $ mkcommit()
  > {
  >    echo $1 > $1
  >    sl add $1
  >    sl ci -m "add $1"
  > }

  $ setconfig remotenames.selectivepulldefault=rbook

Set up extension and repos to clone over wire protocol

  $ configure dummyssh
  $ setconfig phases.publish=false

  $ sl init repo1
  $ sl clone -q ssh://user@dummy/repo1 repo2
  $ cd repo2

Test that anonymous heads are disallowed by default

  $ echo a > a
  $ sl add a
  $ sl commit -m a
  $ sl push
  pushing to ssh://user@dummy/repo1
  searching for changes
  abort: push would create new anonymous heads (cb9a9f314b8b)
  (use --allow-anon to override this warning)
  [255]

Create a remote bookmark

  $ sl push --to @ --create
  pushing rev cb9a9f314b8b to destination ssh://user@dummy/repo1 bookmark @
  searching for changes
  exporting bookmark @
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes

Test that we can still push a head that advances a remote bookmark

  $ echo b >> a
  $ sl commit -m b
  $ sl book @
  $ sl push
  pushing to ssh://user@dummy/repo1
  searching for changes
  updating bookmark @
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes

Test --delete

  $ sl push --delete @
  pushing to ssh://user@dummy/repo1
  searching for changes
  no changes found
  deleting remote bookmark @
  [1]

Test that we don't get an abort if we're doing a bare push that does nothing

  $ sl bookmark -d @
  $ sl push
  pushing to ssh://user@dummy/repo1
  searching for changes
  no changes found
  [1]

Test that we can still push a head if there are no bookmarks in either the
remote or local repo

  $ echo c >> a
  $ sl commit -m c
  $ sl push --allow-anon
  pushing to ssh://user@dummy/repo1
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes


  $ sl log -G -T '{node|short} {bookmarks} {remotebookmarks}\n'
  @  2d95304fed5d
  │
  o  1846eede8b68
  │
  o  cb9a9f314b8b
  
  $ sl bookmark foo
  $ sl push -B foo
  pushing to ssh://user@dummy/repo1
  searching for changes
  no changes found
  exporting bookmark foo
  [1]
  $ sl log -G -T '{node|short} {bookmarks} {remotebookmarks}\n'
  @  2d95304fed5d foo
  │
  o  1846eede8b68
  │
  o  cb9a9f314b8b
  $ sl bookmarks -d foo
  $ sl debugstrip . -q
  $ sl log -G -T '{node|short} {bookmarks} {remotebookmarks}\n'
  @  1846eede8b68
  │
  o  cb9a9f314b8b

  $ sl pull -q
  $ sl push
  pushing to ssh://user@dummy/repo1
  searching for changes
  no changes found
  [1]

Test pushrev configuration option

  $ setglobalconfig remotenames.pushrev=.
  $ echo d >> a
  $ sl commit -qm 'da'
  $ sl push
  pushing to ssh://user@dummy/repo1
  searching for changes
  abort: push would create new anonymous heads (7481df5f123a)
  (use --allow-anon to override this warning)
  [255]

Set up server repo
  $ sl init rnserver
  $ cd rnserver
  $ mkcommit a
  $ sl book -r 'desc(add)' rbook
  $ cd ..

Set up client repo
  $ sl clone rnserver rnclient
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd rnclient
  $ sl book --all
  no bookmarks set
     remote/rbook              1f0dee641bb7
  $ cd ..

Advance a server bookmark to an unknown commit and create a new server bookmark
We want to test both the advancement of locally known remote bookmark and the
creation of a new one (locally unknonw).
  $ cd rnserver
  $ mkcommit b
  $ sl book -r 'max(desc(add))' rbook
  moving bookmark 'rbook' forward from 1f0dee641bb7
  $ sl book -r 'max(desc(add))' rbook2
  $ sl book
     rbook                     7c3bad9141dc
     rbook2                    7c3bad9141dc
  $ cd ..

Force client to get data about new bookmarks without getting commits.
Expect update for the bookmark after the push.
  $ cd rnclient
  $ sl book --all
  no bookmarks set
     remote/rbook              1f0dee641bb7
  $ sl push
  pushing to $TESTTMP/repo2/rnserver
  searching for changes
  no changes found
  [1]
  $ sl book --all
  no bookmarks set
     remote/rbook              7c3bad9141dc

