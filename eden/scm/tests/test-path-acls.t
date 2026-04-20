
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

  $ find .
  A
  regular
  regular/file.txt
