
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable absorb

Commit date defaults to "now" based on tweakdefaults
  $ newrepo
  $ echo foo > a
  $ sl ci -m 'a' -A a
  $ sl log -r . -T '{date}\n'
  0.00
  $ echo bar >> a
  $ sl absorb -qa --config devel.default-date='1 1'
  $ sl log -r . -T '{date}\n'
  1.01

Don't default when absorbkeepdate is set
  $ newrepo
  $ echo foo > a
  $ sl ci -m 'a' -A a
  $ echo bar >> a
  $ sl absorb -qa --config tweakdefaults.absorbkeepdate=true
  $ sl log -r . -T '{desc} {date}\n'
  a 0.00

