
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
  $ sl go -q $A
  abort: Error fetching key Some(Key { path: RepoPathBuf(""), hgid: HgId("19d1f9c4aa6e6b299fa6a863b253889df872ae0f") }): Unauthorized access to manifest under restricted path: 19d1f9c4aa6e6b299fa6a863b253889df872ae0f. Request access via ACL some-acl.
  
  Caused by:
      Error fetching key Some(Key { path: RepoPathBuf(""), hgid: HgId("19d1f9c4aa6e6b299fa6a863b253889df872ae0f") }): Unauthorized access to manifest under restricted path: 19d1f9c4aa6e6b299fa6a863b253889df872ae0f. Request access via ACL some-acl.
  [255]
  $ find .
