  $ export HGIDENTITY=sl
  $ newclientrepo <<EOS
  > B # B/A = (removed)
  > |
  > A
  > EOS
  $ sl go -q $B
  $ touch A
  $ sl add A
  $ LOG=eagerepo::api=debug sl revert -r .^ A 2>&1 | grep history
  DEBUG eagerepo::api: history 005d992c5dcf32993668f7cede29d296c494a5d9
