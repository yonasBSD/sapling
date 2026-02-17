  $ setconfig drawdag.defaultfiles=false

  $ setconfig grep.use-rust=true

  $ newclientrepo
  $ drawdag <<EOS
  > A  # A/apple = apple\n
  >    # A/banana = banana\n
  >    # A/fruits = apple\nbanana\n
  > EOS
  $ hg go -q $A

  $ hg grep apple | sort
  apple:apple
  fruits:apple

  $ hg grep apple path:fruits
  fruits:apple

  $ hg grep doesntexist
  [1]

  $ hg grep 're:(oops'
  abort: invalid grep pattern 're:(oops': Error { kind: Regex("regex parse error:\n    (?:re:(oops)\n    ^\nerror: unclosed group") }
  [255]
