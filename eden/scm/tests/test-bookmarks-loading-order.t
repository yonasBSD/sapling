
#require no-eden


  $ configure modern
  $ setconfig ui.allowemptycommit=1

  $ newrepo
  $ echo A | sl debugdrawdag

Active bookmark.

  $ sl up A -q

Read bookmark while updating it.

With metalog it works fine:

  $ sl log -r A -T '{desc}\n' --config hooks.pre-bookmark-load='sl commit -m A2'
  A

  $ sl log -r A -T '{desc}\n' --config hooks.pre-bookmark-load='sl commit -m A3'
  A2
