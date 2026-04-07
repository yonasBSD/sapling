
#require no-eden

  $ setconfig devel.segmented-changelog-rev-compat=true
  $ configure modern
  $ newrepo
  $ drawdag << 'EOS'
  > A
  > EOS

  $ sl debuginternals
  *	blackbox (glob)
  *	store/hgcommits (glob)
  *	store/indexedlogdatastore (glob) (?)
  *	store/manifests (glob) (?)
  *	store/metalog (glob)
  *	store/mutation (glob)
  *	store/segments (glob)

  $ sl debuginternals -o a.tar.gz 2>/dev/null
  a.tar.gz
