#require fsmonitor no-eden

  $ enable sparse

  $ newclientrepo
  $ sl sparse include include

  $ mkdir include
  $ echo foo > include/include
  $ echo foo > exclude
  $ sl st
  ? include/include
  $ sl commit -Aqm foo

Make sure we aren't tracking "exclude" yet.
  $ sl debugtreestate list
  include/include: * (glob)

Now we should.
  $ setconfig fsmonitor.track-ignore-files=true
  $ sl st
  $ sl debugtreestate list
  exclude: * (glob)
  include/include: * (glob)
