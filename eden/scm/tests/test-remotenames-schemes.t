
#require no-eden


  $ export HGIDENTITY=sl
  $ enable schemes
  $ configure modern

  $ cat >> "$HGRCPATH" << EOF
  > [schemes]
  > foo = eager://$TESTTMP/
  > [remotenames]
  > selectivepulldefault = master, stable
  > EOF

  $ newrepo
  $ echo 'A..C' | drawdag
  $ sl path -a default "foo://server1"
  $ sl push -q --to master --create -r $C
  $ sl push -q --to stable --create -r $B

  $ sl bookmarks --remote
     remote/master                    26805aba1e600a82e93661149f2313866a221a7b
     remote/stable                    112478962961147124edd43549aedd1a335e44bf
