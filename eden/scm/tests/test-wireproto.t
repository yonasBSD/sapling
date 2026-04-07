
#require no-eden

  $ eagerepo

Test wire protocol argument passing

Setup repo:

  $ sl init repo

Local:

  $ sl debugwireargs repo eins zwei --three drei --four vier
  eins zwei drei vier None
  $ sl debugwireargs repo eins zwei --four vier
  eins zwei None vier None
  $ sl debugwireargs repo eins zwei
  eins zwei None None None
  $ sl debugwireargs repo eins zwei --five fuenf
  eins zwei None None fuenf
