
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
  $ setconfig experimental.restricted-tree-mode=enforced
  $ newclientrepo client server

  $ sl debugmanifestdirs -qr $A
  19d1f9c4aa6e6b299fa6a863b253889df872ae0f restricted
  7336b5d3a2867d97ff2b64af2b848b76ac7e7f39 regular
  7ebc6a0e1746ead2f3778301c440cde7eec58620 /

Don't attempt to fetch 19d1f9c4 - it is restricted
  $ LOG=tree_fetches=trace hg go -q $A
  TRACE tree_fetches: attrs=["content"] keys=["@7ebc6a0e"]
  TRACE tree_fetches: attrs=["content"] keys=["@7336b5d3"]

  $ find .
  A
  regular
  regular/file.txt

Give a specific message when referencing a restricted file:
  $ hg cat restricted/secret.txt
  restricted/secret.txt: restricted path
  [1]

  $ hg files restricted/secret.txt
  restricted/secret.txt: restricted path
  [1]

  $ hg files -r . restricted/secret.txt
  restricted/secret.txt: restricted path
  [1]

Make sure root tree has acl indices populated in cache
  $ sl debugscmstore -r $A '' --mode=tree | grep -A 4 acl_children_indices
                          acl_children_indices: Some(
                              [
                                  2,
                              ],
                          ),

After committing a change outside the restricted directory, the new root
tree should still have acl_children_indices for the unchanged restricted directory:
  $ echo modified > regular/file.txt
  $ sl commit -m 'modify regular file'
  $ sl debugscmstore -r . '' --mode=tree | grep -A 4 acl_children_indices
                          acl_children_indices: Some(
                              [
                                  2,
                              ],
                          ),
