#require git no-eden

  $ export HGIDENTITY=sl
  $ . $TESTDIR/git.sh

Initialize the server repos.

  $ git init -q --bare -b main repo-1.git
  $ git init -q --bare -b main repo-2.git

Initialize the Sapling repo.

  $ sl clone -q --git "$TESTTMP/repo-1.git" client-repo
  $ cd client-repo
  $ sl paths --add default-push "$TESTTMP/repo-2.git"
  $ touch testfile
  $ sl add testfile
  $ sl commit testfile -m testcommit

Pushing without specifying a path pushes to the 'default-push' path.

  $ sl push -q -r . --to main --create

  $ GIT_DIR="$TESTTMP/repo-1.git" git log --pretty=format:%s%n
  fatal: your current branch 'main' does not have any commits yet
  [128]

  $ GIT_DIR="$TESTTMP/repo-2.git" git log --pretty=format:%s%n
  testcommit

After deleting the 'default-push' path,
pushing without specifying a path pushes to the 'default' path

  $ sl paths --delete default-push
  $ sl push -q -r . --to main --create

  $ GIT_DIR="$TESTTMP/repo-1.git" git log --pretty=format:%s%n
  testcommit

  $ GIT_DIR="$TESTTMP/repo-2.git" git log --pretty=format:%s%n
  testcommit
