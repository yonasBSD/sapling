#require fsmonitor no-eden

  $ newclientrepo repo
  $ sl status

  $ touch x

At t0:

  $ sl status
  ? x

  $ touch y

  $ sl debugrefreshwatchmanclock
  abort: only automation can run this
  [255]

At t1:

  $ HGPLAIN=1 sl debugrefreshwatchmanclock
  updating watchman clock from '*' to '*' (glob)

Changes between last watchman clock (t0) and "debugrefreshwatchmanclock" (t1) are missed ("touch y")

  $ sl status
  ? x
