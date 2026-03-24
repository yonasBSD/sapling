#require no-eden

does not crash the whole program with bad reposetup:

  $ export HGIDENTITY=sl
  $ newrepo
  $ cat >> a.py << EOF
  > def reposetup(ui, repo):
  >     1 / 0
  > EOF
  $ sl log -r . --config extensions.a=a.py -T'.\n'
  reposetup failed in extension a: division by zero
  .

