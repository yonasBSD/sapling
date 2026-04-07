#modern-config-incompatible

#require no-eden


Setup

  $ configure dummyssh
  $ setconfig ui.username="nobody <no.reply@fb.com>"

Setup pushrebase required repo

  $ sl init server
  $ cd server
  $ enable pushrebase
  $ setconfig pushrebase.blocknonpushrebase=true
  $ echo a > a && sl commit -Aqm a
  $ cd ..

  $ sl clone -q server client
  $ cd client
  $ echo b >> a && sl commit -Aqm b
  $ sl book master

Non-pushrebase pushes should be rejected

  $ sl push --allow-anon
  pushing to $TESTTMP/server
  searching for changes
  error: prechangegroup.blocknonpushrebase hook failed: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  abort: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  [255]

  $ sl push -f --allow-anon
  pushing to $TESTTMP/server
  searching for changes
  error: prechangegroup.blocknonpushrebase hook failed: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  abort: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  [255]

  $ sl push -B master
  pushing to $TESTTMP/server
  searching for changes
  error: prechangegroup.blocknonpushrebase hook failed: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  abort: this repository requires that you enable the pushrebase extension and push using 'sl push --to'
  [255]

Pushrebase pushes should be allowed

  $ sl push --config "extensions.pushrebase=" --to master --create
  pushing rev 1846eede8b68 to destination $TESTTMP/server bookmark master
  searching for changes
  pushing 1 changeset:
      1846eede8b68  b
  exporting bookmark master

Bookmark pushes should not be affected by the block

  $ sl book -r ".^" master -f
  $ sl push -B master
  pushing to $TESTTMP/server
  searching for changes
  no changes found
  updating bookmark master
  [1]
  $ sl -R ../server log -T '{bookmarks}' -G
  o
  │
  @  master
  
