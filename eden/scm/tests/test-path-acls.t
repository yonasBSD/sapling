
#require no-eden

  $ newserver server
  $ drawdag << 'EOS'
  > A  # A/regular/file.txt = regular content
  >    # A/restricted/.slacl = acl config
  >    # A/restricted/secret.txt = secret content
  > EOS

  $ cd
  $ setconfig scmstore.fetch-tree-aux-data=true
  $ setconfig scmstore.tree-metadata-mode=always
  $ newclientrepo client server

  $ sl debugmanifestdirs -qr $A
  19d1f9c4aa6e6b299fa6a863b253889df872ae0f restricted
  7336b5d3a2867d97ff2b64af2b848b76ac7e7f39 regular
  7ebc6a0e1746ead2f3778301c440cde7eec58620 /

FIXME: don't attempt to fetch 19d1f9c4 - it is restricted
  $ LOG=tree_fetches=trace hg go -q $A
  TRACE tree_fetches: attrs=["content"] keys=["@7ebc6a0e"]
  TRACE tree_fetches: attrs=["content"] keys=["@19d1f9c4", "@7336b5d3"]

  $ find .
  A
  regular
  regular/file.txt
