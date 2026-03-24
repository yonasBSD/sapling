
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Setup

  $ enable myparent
  $ sl init repo
  $ cd repo
  $ touch foo
  $ cat >> ../commitmessage << EOF
  > [prefix] My title
  > 
  > Summary: Very good summary of my commit.
  > 
  > Test Plan: cat foo
  > 
  > Reviewers: #sourcecontrol, rmcelroy
  > 
  > Subscribers: rmcelroy, mjpieters
  > 
  > Differential Revision: https://phabricator.fb.com/D42
  > 
  > Tasks: 1337
  > 
  > Tags: mercurial
  > EOF
  $ sl commit -qAl ../commitmessage
  $ touch bar
  $ sl commit -qAm 'Differential Revision: https://phabricator.fb.com/D2'

All template keywords work if the current author matches the other of the
previous commit.

  $ sl log -T '{myparentdiff}\n' -r .
  D42
  $ sl log -T '{myparentreviewers}\n' -r .
  #sourcecontrol, rmcelroy
  $ sl log -T '{myparentsubscribers}\n' -r .
  rmcelroy, mjpieters
  $ sl log -T '{myparenttasks}\n' -r .
  1337
  $ sl log -T '{myparenttitleprefix}\n' -r .
  [prefix]
  $ sl log -T '{myparenttags}\n' -r .
  mercurial

If the authors do not match the keywords will be empty.

  $ sl commit -q --amend --user hacker2
  $ sl log -T '{myparentdiff}' -r .
  $ sl log -T '{myparentreviewers}' -r .
  $ sl log -T '{myparentsubscribers}' -r .
  $ sl log -T '{myparenttasks}' -r .
  $ sl log -T '{myparenttitleprefix}' -r .
  $ sl log -T '{myparenttags}' -r .

Ensure multiple prefixes tags are supported

  $ touch baz
  $ sl commit -qAm '[long tag][ tag2][tag3 ] [tags must be connected] Adding baz'
  $ touch foobar
  $ sl commit -qAm 'Child commit'
  $ sl log -T '{myparenttitleprefix}\n' -r .
  [long tag][ tag2][tag3 ]

Test colon prefix style

  $ touch qux
  $ sl commit -qAm 'eden/fs: fix something'
  $ touch quux
  $ sl commit -qAm 'Child of colon style'
  $ sl log -T '{myparenttitleprefix}\n' -r .

  $ sl log -T '{myparenttitleprefix}\n' -r . --config myparent.prefix-style=colon
  eden/fs:
  $ touch corge
  $ sl commit -qAm 'prefix/tag1/tag2: nested path style'
  $ touch grault
  $ sl commit -qAm 'Another child'
  $ sl log -T '{myparenttitleprefix}\n' -r . --config myparent.prefix-style=colon
  prefix/tag1/tag2:

Test colon style with spaces in prefix

  $ touch space1
  $ sl commit -qAm 'rust/some project: add feature'
  $ touch space2
  $ sl commit -qAm 'child of spaced prefix'
  $ sl log -T '{myparenttitleprefix}\n' -r . --config myparent.prefix-style=colon
  rust/some project:

Make sure the template keywords are documented correctly

  $ sl help templates | grep myparent
      myparentdiff  Show the differential revision of the commit's parent, if it
      myparentreviewers
      myparentsubscribers
      myparenttags  Show the tags from the commit's parent, if it has the same
      myparenttasks
      myparenttitleprefix
