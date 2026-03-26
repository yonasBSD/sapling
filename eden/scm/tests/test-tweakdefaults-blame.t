
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true

Test wrapped blame to be able to handle the usual command line attributes
  $ sl init repo
  $ cd repo
  $ echo "line one" > a
  $ echo "line two" >> a
  $ sl ci -Am "Differential Revision: https://phabricator.fb.com/D111111"
  adding a
  $ echo "line three" >> a
  $ sl ci -Am "Differential Revision: https://phabricator.fb.com/D222222"
  $ sl blame a
  37b9ff139054: line one
  37b9ff139054: line two
  05d474df3f59: line three
  $ sl blame --user a
  test: line one
  test: line two
  test: line three
  $ sl blame --date a
  Thu Jan 01 00:00:00 1970 +0000: line one
  Thu Jan 01 00:00:00 1970 +0000: line two
  Thu Jan 01 00:00:00 1970 +0000: line three
  $ sl blame --number a
  0: line one
  0: line two
  1: line three
  $ sl blame --changeset --file --line-number a
  37b9ff139054 a:1: line one
  37b9ff139054 a:2: line two
  05d474df3f59 a:3: line three
  $ sl blame --user --date --changeset --line-number a
  test 37b9ff139054 Thu Jan 01 00:00:00 1970 +0000:1: line one
  test 37b9ff139054 Thu Jan 01 00:00:00 1970 +0000:2: line two
  test 05d474df3f59 Thu Jan 01 00:00:00 1970 +0000:3: line three
  $ sl blame -p a
    D111111: line one
    D111111: line two
    D222222: line three
  $ sl blame -p --date a
    D111111 Thu, 01 Jan 1970 00:00:00 +0000: line one
    D111111 Thu, 01 Jan 1970 00:00:00 +0000: line two
    D222222 Thu, 01 Jan 1970 00:00:00 +0000: line three
  $ sl blame -p --date --quiet a
    D111111 1970-01-01: line one
    D111111 1970-01-01: line two
    D222222 1970-01-01: line three
