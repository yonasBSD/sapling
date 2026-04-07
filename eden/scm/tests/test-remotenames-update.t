
#require no-eden


  $ eagerepo
Set up repo

  $ sl init repo
  $ cd repo
  $ echo 'foo'> a.txt
  $ sl add a.txt
  $ sl commit -m "a"
  $ echo 'bar' > b.txt
  $ sl add b.txt
  $ sl commit -m "b"
  $ sl bookmark foo -i
  $ echo 'bar' > c.txt
  $ sl add c.txt
  $ sl commit -q -m "c"

Testing update -B feature

  $ sl log -G -T '{bookmarks} {remotebookmarks}'
  @
  │
  o  foo
  │
  o
  

  $ sl goto -B bar foo
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark foo)
  $ sl log -G -T '{bookmarks} {remotebookmarks}'
  o
  │
  @  bar foo
  │
  o
  
  $ sl bookmarks -v
   * bar                       661086655130[foo]
     foo                       661086655130

  $ sl goto -B foo bar
  abort: bookmark 'foo' already exists
  [255]

