#require git no-windows no-eden

  $ . $TESTDIR/git.sh
  $ setconfig diff.git=1

Prepare git repo with submodules

  $ git init -q -b main sub
  $ cd sub
  $ touch a
  $ sl commit -m 'Add a' -A a
  $ echo 1 >> a
  $ sl commit -m 'Modify a' -A a

  $ cd
  $ git init -q -b main parent
  $ cd parent
  $ git submodule --quiet add -b main ../sub
  $ git commit -qm 'add .gitmodules'

Status does not contain submodule if submodule is not changed:

  $ touch b
  $ sl status
  ? b

Status and diff can include submodule:

  $ cd sub
  $ git checkout -q 'HEAD^'
  $ cd ..

  $ sl status
  M sub
  ? b

  $ sl diff
  diff --git a/sub b/sub
  --- a/sub
  +++ b/sub
  @@ -1,1 +1,1 @@
  -Subproject commit 838d36ce8147047ed2fb694a88ea81cdfa5041b0
  +Subproject commit 7e03c5d593048a97b91470d7c33dc07e007aa5a4

Status from submodule:

  $ cd sub
  $ touch c
  $ sl status
  ? c

Committing from submodule:

  $ sl add c
  $ sl commit -m c

Checking out from submodule:

  $ sl prev
  update complete
  [7e03c5] Add a

  $ sl status

Committing from parent repo:

  $ cd ~/parent
  $ sl status sub
  M sub

  $ sl commit -m 'Modify submodule'

  $ sl status sub

  $ sl log -r . -p
  commit:      d59fa9b13e55
  user:        test <>
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     Modify submodule
  
  diff --git a/sub b/sub
  --- a/sub
  +++ b/sub
  @@ -1,1 +1,1 @@
  -Subproject commit 838d36ce8147047ed2fb694a88ea81cdfa5041b0
  +Subproject commit 7e03c5d593048a97b91470d7c33dc07e007aa5a4
