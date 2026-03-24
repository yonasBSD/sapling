#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ sl init a

  $ echo a > a/a
  $ sl --cwd a ci -Ama
  adding a

  $ sl clone a c
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl clone a b
  updating to tip
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo b >> b/a
  $ sl --cwd b ci -mb

Push should provide a hint when both 'default' and 'default-push' not set:
  $ cd c
  $ sl push --config paths.default=
  abort: default repository not configured!
  (see 'sl help config.paths')
  [255]

  $ cd ..

Push should push to 'default' when 'default-push' not set:

  $ sl --cwd b push --allow-anon
  pushing to $TESTTMP/a
  searching for changes
  adding changesets
  adding manifests
  adding file changes

Push should push to 'default-push' when set:

  $ echo '[paths]' >> b/.sl/config
  $ echo 'default-push = ../c' >> b/.sl/config
  $ sl --cwd b push --allow-anon
  pushing to $TESTTMP/c
  searching for changes
  adding changesets
  adding manifests
  adding file changes

But push should push to 'default' if explicitly specified (issue5000):

  $ sl --cwd b push default
  pushing to $TESTTMP/a
  searching for changes
  no changes found
  [1]

Push should push to 'default-push' when 'default' is not set

  $ sl -q clone a push-default-only
  $ cd push-default-only
  $ rm .sl/config

  $ touch foo
  $ sl -q commit -A -m 'add foo'
  $ sl --config paths.default-push=../a push --allow-anon
  pushing to $TESTTMP/a
  searching for changes
  adding changesets
  adding manifests
  adding file changes

  $ cd ..

Pushing to a path that isn't defined should not fall back to default

  $ sl --cwd b push doesnotexist
  abort: repository doesnotexist does not exist!
  [255]

:pushurl is used when defined

  $ sl -q clone a pushurlsource
  $ sl -q clone a pushurldest
  $ cd pushurlsource

Windows needs a leading slash to make a URL that passes all of the checks
  $ WD=`pwd`
#if windows
  $ WD="/$WD"
#endif
  $ cat > .sl/config << EOF
  > [paths]
  > default = https://example.com/not/relevant
  > default:pushurl = file://$WD/../pushurldest
  > EOF

  $ touch pushurl
  $ sl -q commit -A -m 'add pushurl'
  $ sl push --allow-anon
  pushing to file:/*/$TESTTMP/pushurlsource/../pushurldest (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes

:pushrev is used when no -r is passed

  $ cat >> .sl/config << EOF
  > default:pushrev = .
  > EOF
  $ sl -q up -r cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b
  $ echo head1 > foo
  $ sl -q commit -A -m head1
  $ sl -q up -r cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b
  $ echo head2 > foo
  $ sl -q commit -A -m head2
  $ sl push -f --allow-anon
  pushing to file:/*/$TESTTMP/pushurlsource/../pushurldest (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes

  $ sl --config 'paths.default:pushrev=draft()' push -f --allow-anon
  pushing to file:/*/$TESTTMP/pushurlsource/../pushurldest (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes

Invalid :pushrev raises appropriately

  $ sl --config 'paths.default:pushrev=notdefined()' push
  pushing to file:/*/$TESTTMP/pushurlsource/../pushurldest (glob)
  sl: parse error: unknown identifier: notdefined
  [255]

  $ sl --config 'paths.default:pushrev=(' push
  pushing to file:/*/$TESTTMP/pushurlsource/../pushurldest (glob)
  sl: parse error at 1: not a prefix: end
  ((
    ^ here)
  [255]

  $ cd ..
