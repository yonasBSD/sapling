#require no-eden


  $ sl init a
  $ sl clone a b
  updating to tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd a

With no paths:

  $ sl paths
  $ sl paths unknown
  not found!
  [1]
  $ sl paths -Tjson
  [
  ]

With paths:

  $ echo '[paths]' >> .sl/config
  $ echo 'dupe = ../b#tip' >> .sl/config
  $ echo 'expand = $SOMETHING/bar' >> .sl/config
  $ cd ..
  $ cd a
  $ sl paths
  dupe = $TESTTMP/b#tip
  expand = $TESTTMP/a/$SOMETHING/bar
  $ SOMETHING=foo sl paths
  dupe = $TESTTMP/b#tip
  expand = $TESTTMP/a/foo/bar
#if msys
  $ SOMETHING=//foo sl paths
  dupe = $TESTTMP/b#tip
  expand = \\foo\bar
#else
  $ SOMETHING=/foo sl paths
  dupe = $TESTTMP/b#tip
  expand = /foo/bar
#endif
  $ sl paths -q
  dupe
  expand
  $ sl paths dupe
  $TESTTMP/b#tip
  $ sl paths -q dupe
  $ sl paths unknown
  not found!
  [1]
  $ sl paths -q unknown
  [1]

formatter output with paths:

  $ echo 'dupe:pushurl = https://example.com/dupe' >> .sl/config
  $ sl paths -Tjson | sed 's|\\\\|\\|g'
  [
   {
    "name": "dupe",
    "pushurl": "https://example.com/dupe",
    "url": "$TESTTMP/b#tip"
   },
   {
    "name": "expand",
    "url": "$TESTTMP/a/$SOMETHING/bar"
   }
  ]
  $ sl paths -Tjson dupe | sed 's|\\\\|\\|g'
  [
   {
    "name": "dupe",
    "pushurl": "https://example.com/dupe",
    "url": "$TESTTMP/b#tip"
   }
  ]
  $ sl paths -Tjson -q unknown
  [
  ]
  [1]

log template:

 (behaves as a {name: path-string} dict by default)

  $ sl log -rnull -T '{peerurls}\n'
  dupe=$TESTTMP/b#tip expand=$TESTTMP/a/$SOMETHING/bar
  $ sl log -rnull -T '{join(peerurls, "\n")}\n'
  dupe=$TESTTMP/b#tip
  expand=$TESTTMP/a/$SOMETHING/bar
  $ sl log -rnull -T '{peerurls % "{name}: {url}\n"}'
  dupe: $TESTTMP/b#tip
  expand: $TESTTMP/a/$SOMETHING/bar
  $ sl log -rnull -T '{get(peerurls, "dupe")}\n'
  $TESTTMP/b#tip

 (sub options can be populated by map/dot operation)

  $ sl log -rnull \
  > -T '{get(peerurls, "dupe") % "url: {url}\npushurl: {pushurl}\n"}'
  url: $TESTTMP/b#tip
  pushurl: https://example.com/dupe
  $ sl log -rnull -T '{peerurls.dupe.pushurl}\n'
  https://example.com/dupe

 (in JSON, it's a dict of urls)

  $ sl log -rnull -T '{peerurls|json}\n' | sed 's|\\\\|/|g'
  {"dupe": "$TESTTMP/b#tip", "expand": "$TESTTMP/a/$SOMETHING/bar"}

password should be masked in plain output, but not in machine-readable/template
output:

  $ echo 'insecure = http://foo:insecure@example.com/' >> .sl/config
  $ sl paths insecure
  http://foo:***@example.com/
  $ sl paths -Tjson insecure
  [
   {
    "name": "insecure",
    "url": "http://foo:insecure@example.com/"
   }
  ]
  $ sl log -rnull -T '{get(peerurls, "insecure")}\n'
  http://foo:insecure@example.com/

  $ cd ..

sub-options for an undeclared path are ignored

  $ sl init suboptions
  $ cd suboptions

  $ cat > .sl/config << EOF
  > [paths]
  > path0 = https://example.com/path0
  > path1:pushurl = https://example.com/path1
  > EOF
  $ sl paths
  path0 = https://example.com/path0

unknown sub-options aren't displayed

  $ cat > .sl/config << EOF
  > [paths]
  > path0 = https://example.com/path0
  > path0:foo = https://example.com/path1
  > EOF

  $ sl paths
  path0 = https://example.com/path0

:pushurl must be a URL

  $ cat > .sl/config << EOF
  > [paths]
  > default = /path/to/nothing
  > default:pushurl = /not/a/url
  > EOF

  $ sl paths
  (paths.default:pushurl not a URL; ignoring)
  default = /path/to/nothing

