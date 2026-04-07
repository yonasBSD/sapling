
#require no-eden


  $ eagerepo
  $ enable amend rebase tweakdefaults
  $ configure mutation-norecord

Setup repo
  $ sl init opawarerepo
  $ cd opawarerepo
  $ echo root > root && sl ci -Am root
  adding root

Check amend metadata
  $ echo a > a && sl ci -Am a
  adding a
  $ echo aa > a && sl amend
  $ sl debugobsolete

Check rebase metadata
  $ sl book -r . destination
  $ sl up 'desc(root)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo b > b && sl ci -Am b
  adding b
  $ sl rebase -r . -d destination
  rebasing 1e9a3c00cbe9 "b"
  $ sl debugobsolete
