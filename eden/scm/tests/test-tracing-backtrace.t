#require no-eden

  $ SL_LOG=commands::run::blocked=debug SL_BTLOG=commands::run::blocked=debug sl version -q
  Sapling * (glob)
  DEBUG commands::run::blocked: * (glob)
  Backtrace (commands::run::blocked):
  ...
