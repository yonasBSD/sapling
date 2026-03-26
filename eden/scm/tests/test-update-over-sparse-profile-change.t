
#require no-eden

  $ export HGIDENTITY=sl
  $ setconfig experimental.nativecheckout=true

test sparse

  $ newclientrepo
  $ enable sparse

  $ echo a > show
  $ echo a > show2
  $ echo c > show3
  $ echo x > hide
  $ cat >> .sparse-include <<EOF
  > [include]
  > show
  > .sparse-include
  > EOF
  $ sl add .sparse-include
  $ sl ci -Aqm 'initial'
  $ sl sparse enable .sparse-include
  $ ls
  show
  $ cat >> .sparse-include <<EOF
  > [include]
  > show
  > show2
  > EOF
  $ sl ci -Am 'second'
  $ sl up -q 'desc(initial)'
  $ ls
  show
  $ sl up -q 'desc(second)'
  $ ls
  show
  show2
#if no-windows
  $ cat >> .sparse-include <<EOF
  > [include]
  > show
  > show2
  > show3
  > EOF
  $ sl ci -m "third"
  $ chmod +x show3
  $ sl ci -m "fourth"
  $ sl up -q 'desc(second)'
  $ ls
  show
  show2
  $ sl up -q 'desc(fourth)'
  $ ls
  show
  show2
  show3
#endif

