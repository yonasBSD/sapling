#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ setconfig remotenames.rename.default=remote remotenames.disallowedto="^remote/"

Init the original "remote" repo

  $ sl init orig
  $ cd orig
  $ echo something > something
  $ sl ci -Am something
  adding something
  $ sl bookmark ababagalamaga
  $ cd ..

Clone original repo

  $ sl clone orig cloned
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd cloned
  $ echo somethingelse > something
  $ sl ci -m somethingelse

Try to push with "remote/"

  $ sl push --to remote/ababagalamaga
  pushing rev 71b4c8f22183 to destination $TESTTMP/orig bookmark ababagalamaga
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark ababagalamaga

Try to push without "remote/", should push to the same bookmark as above

  $ sl push --to ababagalamaga
  pushing rev 71b4c8f22183 to destination $TESTTMP/orig bookmark ababagalamaga
  searching for changes
  remote bookmark already points at pushed rev
  no changes found
  [1]

Set up an svn default push path and test behavior

  $ sl paths --add default-push svn+ssh://nowhere/in/particular
  $ sl push --to foo ../orig
  pushing rev 71b4c8f22183 to destination ../orig bookmark foo
  searching for changes
  abort: not creating new remote bookmark
  (use --create to create a new bookmark)
  [255]
