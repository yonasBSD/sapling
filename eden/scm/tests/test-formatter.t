
#require no-eden


  $ export HGIDENTITY=sl
  $ setconfig config.use-rust=True
We need to set edenapi.url for now since working copy at the moment requires this to be set

Test config:
  $ setconfig testsection.subsection1=foo
  $ setconfig testsection.subsection2=bar
  $ sl --config foo.bar=baz config testsection
  testsection.subsection1=foo
  testsection.subsection2=bar
  $ sl --config foo.bar=baz config foo -Tjson
  [
  {
    "name": "foo.bar",
    "source": "--config",
    "value": "baz"
  }
  ]
  $ sl --config foo.bar=baz config foo -Tdebug
  config = [
      {'source': '--config', 'name': 'foo.bar', 'value': 'baz'},
  ]
  $ sl --config foo.bar=baz config foo.bar
  baz
  $ sl --config foo.bar=baz config foo.bar -Tjson
  [
  {
    "name": "foo.bar",
    "source": "--config",
    "value": "baz"
  }
  ]
  $ sl --config foo.bar=baz config foo.bar -Tdebug
  config = [
      {'source': '--config', 'value': 'baz', 'name': 'foo.bar'},
  ]
  $ sl config testsection
  testsection.subsection1=foo
  testsection.subsection2=bar
  $ sl config testsection --debug
  *hgrc:*: testsection.subsection1=foo (glob)
  *hgrc:*: testsection.subsection2=bar (glob)
  $ sl config testsection -Tdebug
  config = [
      {'source': '*hgrc:*', 'name': 'testsection.subsection1', 'value': 'foo'}, (glob)
      {'source': '*hgrc:*', 'name': 'testsection.subsection2', 'value': 'bar'}, (glob)
  ]
  $ sl config testsection -Tjson
  [
  {
    "name": "testsection.subsection1",
    "source": "*hgrc:*", (glob)
    "value": "foo"
  },
  {
    "name": "testsection.subsection2",
    "source": "*hgrc:*", (glob)
    "value": "bar"
  }
  ]
  $ sl config testsection.subsection1
  foo
  $ sl config testsection.subsection1 --debug
  *hgrc:* foo (glob)
  $ sl config testsection.subsection1 -Tdebug
  config = [
      {'source': '*hgrc:*', 'value': 'foo', 'name': 'testsection.subsection1'}, (glob)
  ]
  $ sl config testsection.subsection1 -Tjson
  [
  {
    "name": "testsection.subsection1",
    "source": "*hgrc:*", (glob)
    "value": "foo"
  }
  ]

Test status:
  $ newclientrepo testrepo
  $ touch file0
  $ sl add
  adding file0
At the moment the working copy, which the status command uses, requires having at least one commit on the repo
  $ sl commit -m "A commit should make things better"
  $ touch file1
  $ touch file2
  $ sl status
  ? file1
  ? file2
  $ sl status -Tdebug
  status = [
      {'status': '?', 'path': 'file1'},
      {'status': '?', 'path': 'file2'},
  ]
  $ sl status -Tjson
  [
  {
    "path": "file1",
    "status": "?"
  },
  {
    "path": "file2",
    "status": "?"
  }
  ]
