#require no-eden

FIXME: "sl status --change" should warn when results may be incomplete due
to restricted paths, and exit non-zero.

Status across a commit with both ACL'd and non-ACL'd files:

  $ newserver server1
  $ drawdag << 'EOS'
  > B  # B/regular/file.txt = updated content
  >    # B/restricted/.slacl = acl config
  >    # B/restricted/secret.txt = updated secret
  > |
  > A  # A/regular/file.txt = regular content
  >    # A/restricted/.slacl = acl config
  >    # A/restricted/secret.txt = secret content
  > EOS

  $ cd
  $ setconfig scmstore.fetch-tree-aux-data=true
  $ setconfig scmstore.tree-metadata-mode=always
  $ newclientrepo client1 server1
  $ sl go -q $B

FIXME: should also warn about restricted/secret.txt being omitted
  $ sl status --change $B
  A B
  A regular/file.txt

Status across a commit with only ACL'd files:

  $ newserver server2
  $ drawdag << 'EOS'
  > B  # B/restricted/.slacl = acl config
  >    # B/restricted/secret.txt = updated secret
  > |
  > A  # A/restricted/.slacl = acl config
  >    # A/restricted/secret.txt = secret content
  > EOS

  $ cd
  $ setconfig scmstore.fetch-tree-aux-data=true
  $ setconfig scmstore.tree-metadata-mode=always
  $ newclientrepo client2 server2
  $ sl go -q $B

FIXME: should warn about restricted paths
  $ sl status --change $B
  A B

Status across a commit that adds an ACL to an existing directory:

  $ newserver server3
  $ drawdag << 'EOS'
  > B  # B/dir/.slacl = acl config
  >    # B/dir/file.txt = content
  > |
  > A  # A/dir/file.txt = content
  > EOS

  $ cd
  $ setconfig scmstore.fetch-tree-aux-data=true
  $ setconfig scmstore.tree-metadata-mode=always
  $ newclientrepo client3 server3
  $ sl go -q $B

FIXME: should warn that dir/ is now restricted and results may differ
  $ sl status --change $B
  A B

Status across a commit that removes an ACL from a directory:

  $ newserver server4
  $ drawdag << 'EOS'
  > B  # B/dir/file.txt = content
  > |
  > A  # A/dir/.slacl = acl config
  >    # A/dir/file.txt = content
  > EOS

  $ cd
  $ setconfig scmstore.fetch-tree-aux-data=true
  $ setconfig scmstore.tree-metadata-mode=always
  $ newclientrepo client4 server4
  $ sl go -q $B

FIXME: A side was restricted so results may be incomplete
  $ sl status --change $B
  A B
