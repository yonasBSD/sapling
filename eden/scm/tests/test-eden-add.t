
#require eden

setup backing repo
  $ newclientrepo

  $ touch rootfile.txt
  $ mkdir dir1
  $ touch dir1/a.txt
  $ echo "original contents" >> dir1/a.txt
  $ sl add rootfile.txt dir1/a.txt
  $ sl commit -m "Initial commit."

test basic sl add operations

  $ touch dir1/b.txt
  $ mkdir dir2
  $ touch dir2/c.txt

  $ sl status
  ? dir1/b.txt
  ? dir2/c.txt

  $ sl debugdirstate --json
  {}

  $ sl add dir2
  adding dir2/c.txt

  $ sl status
  A dir2/c.txt
  ? dir1/b.txt

  $ sl debugdirstate --json
  {"dir2/c.txt": {"merge_state": -1, "merge_state_string": "MERGE_BOTH", "mode": 0, "status": "a"}}

  $ sl rm --force dir1/a.txt
  $ echo "original contents" > dir1/a.txt
  $ touch dir1/a.txt

  $ sl status
  A dir2/c.txt
  R dir1/a.txt
  ? dir1/b.txt

  $ sl add .
  adding dir1/a.txt
  adding dir1/b.txt

  $ sl status
  A dir1/b.txt
  A dir2/c.txt

  $ sl rm dir1/a.txt
  $ echo "different contents" > dir1/a.txt
  $ sl add dir1
  adding dir1/a.txt

  $ sl status
  M dir1/a.txt
  A dir1/b.txt
  A dir2/c.txt

  $ sl rm --force dir1/a.txt
  $ sl add dir1

  $ sl status
  A dir1/b.txt
  A dir2/c.txt
  R dir1/a.txt

  $ sl add dir3
  dir3: $ENOENT$
  [1]
