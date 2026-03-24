
#require no-eden

#inprocess-hg-incompatible

Create an extension to test bundle2 with multiple changegroups

  $ export HGIDENTITY=sl
  $ cat > bundle2.py <<EOF
  > """
  > """
  > from sapling import changegroup, discovery, exchange
  > 
  > def _getbundlechangegrouppart(bundler, repo, source, bundlecaps=None,
  >                               b2caps=None, heads=None, common=None,
  >                               **kwargs):
  >     # Create two changegroups given the common changesets and heads for the
  >     # changegroup part we are being requested. Use the parent of each head
  >     # in 'heads' as intermediate heads for the first changegroup.
  >     intermediates = [repo[r].p1().node() for r in heads]
  >     outgoing = discovery.outgoing(repo, common, intermediates)
  >     cg = changegroup.makechangegroup(repo, outgoing, '02',
  >                                      source, bundlecaps=bundlecaps)
  >     bundler.newpart('output', data=b'changegroup1')
  >     part = bundler.newpart('changegroup', data=cg.getchunks())
  >     part.addparam('version', '02')
  >     outgoing = discovery.outgoing(repo, common + intermediates, heads)
  >     cg = changegroup.makechangegroup(repo, outgoing, '02',
  >                                      source, bundlecaps=bundlecaps)
  >     bundler.newpart('output', data=b'changegroup2')
  >     part = bundler.newpart('changegroup', data=cg.getchunks())
  >     part.addparam('version', '02')
  > 
  > def _pull(repo, *args, **kwargs):
  >   pullop = _orig_pull(repo, *args, **kwargs)
  >   repo.ui.write('pullop.cgresult is %d\n' % pullop.cgresult)
  >   return pullop
  > 
  > _orig_pull = exchange.pull
  > exchange.pull = _pull
  > exchange.getbundle2partsmapping['changegroup'] = _getbundlechangegrouppart
  > EOF

  $ cat >> $HGRCPATH << EOF
  > [ui]
  > logtemplate={node|short} {phase} {author} {bookmarks} {desc|firstline}
  > EOF

Start with a simple repository with a single commit

  $ newclientrepo repo
  $ cat >> .sl/config << EOF
  > [extensions]
  > bundle2=$TESTTMP/bundle2.py
  > EOF

  $ echo A > A
  $ sl commit -A -m A -q
  $ sl push -q -r . --to head1 --create
  $ cd ..

Clone

  $ newclientrepo clone repo_server head1

Add two linear commits

  $ cd ../repo
  $ echo B > B
  $ sl commit -A -m B -q
  $ echo C > C
  $ sl commit -A -m C -q
  $ sl push -q -r . --to head1

  $ cd ../clone
  $ cat >> .sl/config <<EOF
  > [hooks]
  > pretxnchangegroup = sh -c "printenv.py pretxnchangegroup"
  > changegroup = sh -c "printenv.py changegroup"
  > EOF

Pull the new commits in the clone

  $ sl pull
  pulling from test:repo_server
  searching for changes
  $ sl goto tip
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -G
  @  f838bfaca5c7 public test  C
  │
  o  27547f69f254 public test  B
  │
  o  4a2df7238c3b public test  A
  
Add more changesets with multiple heads to the original repository

  $ cd ../repo
  $ echo D > D
  $ sl commit -A -m D -q
  $ sl push -q -r . --to head1
  $ sl up -r 'desc(B)'
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo E > E
  $ sl commit -A -m E -q
  $ echo F > F
  $ sl commit -A -m F -q
  $ sl push -q -r . --to head2 --create
  $ sl up -r 'desc(B)'
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo G > G
  $ sl commit -A -m G -q
  $ sl push -q -r . --to head3 --create
  $ sl up -r 'desc(D)'
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo H > H
  $ sl commit -A -m H -q
  $ sl push -q -r . --to head4 --create
  $ sl log -G
  @  5cd59d311f65 draft test  H
  │
  │ o  1d14c3ce6ac0 draft test  G
  │ │
  │ │ o  7f219660301f draft test  F
  │ │ │
  │ │ o  8a5212ebc852 draft test  E
  │ ├─╯
  o │  b3325c91a4d9 draft test  D
  │ │
  o │  f838bfaca5c7 draft test  C
  ├─╯
  o  27547f69f254 draft test  B
  │
  o  4a2df7238c3b draft test  A
  
New heads are reported during transfer and properly accounted for in
pullop.cgresult

  $ cd ../clone
  $ sl pull -B head1 -B head2 -B head3 -B head4
  pulling from test:repo_server
  searching for changes
  $ sl log -G
  o  5cd59d311f65 public test  H
  │
  o  b3325c91a4d9 public test  D
  │
  │ o  1d14c3ce6ac0 public test  G
  │ │
  │ │ o  7f219660301f public test  F
  │ │ │
  │ │ o  8a5212ebc852 public test  E
  │ ├─╯
  @ │  f838bfaca5c7 public test  C
  ├─╯
  o  27547f69f254 public test  B
  │
  o  4a2df7238c3b public test  A
  
Removing a head from the original repository by merging it

  $ cd ../repo
  $ sl merge -r 'desc(G)' -q
  $ sl commit -m Merge
  $ echo I > I
  $ sl commit -A -m H -q
  $ sl push -q -r . --to head4
  $ sl log -G
  @  9d18e5bd9ab0 draft test  H
  │
  o    71bd7b46de72 draft test  Merge
  ├─╮
  │ o  5cd59d311f65 draft test  H
  │ │
  o │  1d14c3ce6ac0 draft test  G
  │ │
  │ │ o  7f219660301f draft test  F
  │ │ │
  │ │ o  8a5212ebc852 draft test  E
  ├───╯
  │ o  b3325c91a4d9 draft test  D
  │ │
  │ o  f838bfaca5c7 draft test  C
  ├─╯
  o  27547f69f254 draft test  B
  │
  o  4a2df7238c3b draft test  A
  
Removed heads are reported during transfer and properly accounted for in
pullop.cgresult

  $ cd ../clone
  $ sl pull -B head4
  pulling from test:repo_server
  searching for changes
  $ sl log -G
  o  9d18e5bd9ab0 public test  H
  │
  o    71bd7b46de72 public test  Merge
  ├─╮
  │ o  5cd59d311f65 public test  H
  │ │
  │ o  b3325c91a4d9 public test  D
  │ │
  o │  1d14c3ce6ac0 public test  G
  │ │
  │ │ o  7f219660301f public test  F
  │ │ │
  │ │ o  8a5212ebc852 public test  E
  ├───╯
  │ @  f838bfaca5c7 public test  C
  ├─╯
  o  27547f69f254 public test  B
  │
  o  4a2df7238c3b public test  A
  
