#require no-eden

  $ newclientrepo
  $ touch file
  $ sl commit -Aqm initial
  $ mkdir dir
  $ touch dir/foo
  $ sl commit -Aqm dir-added
  $ sl debugdiffdirs -r .^ -r .
  A dir

  $ echo >> dir/foo
  $ sl commit -Aqm file-modify
  $ sl debugdiffdirs -r .^ -r .

  $ touch dir/bar
  $ sl commit -Aqm file-added
  $ sl debugdiffdirs -r .^ -r .
  M dir

  $ sl rm dir/bar
  $ sl commit -Aqm file-removed
  $ sl debugdiffdirs -r .^ -r .
  M dir

  $ mkdir dir/nested
  $ touch dir/nested/poo
  $ sl commit -Aqm nested-added
  $ sl debugdiffdirs -r .^ -r .
  M dir
  A dir/nested

  $ sl rm dir/nested/poo
  $ touch dir/nested
  $ sl commit -Aqm nested-replaced
  $ sl debugdiffdirs -r .^ -r .
  M dir
  R dir/nested

  $ sl rm dir/nested
  $ mkdir dir/nested
  $ touch dir/nested/poo
  $ sl commit -Aqm nested-replaced-reverse
  $ sl debugdiffdirs -r .^ -r .
  M dir
  A dir/nested

  $ sl rm dir/nested
  removing dir/nested/poo
  $ sl commit -Aqm nested-removed

  $ sl rm dir/foo
  $ sl commit -Aqm dir-removed
  $ sl debugdiffdirs -r .^ -r .
  R dir

  $ sl debugdiffdirs -r 'desc("file-removed")' -r .
  R dir

  $ sl debugdiffdirs -r 'desc("initial")' -r 'desc("file-removed")'
  A dir

  $ sl debugdiffdirs -r 'desc("initial")' -r .
