#require no-eden


  $ export HGIDENTITY=sl
  $ enable commitcloud
  $ disable infinitepush
  $ setconfig remotenames.autopullhoistpattern='re:.*'
  $ setconfig infinitepush.branchpattern="re:scratch/.+"

  $ newserver server
  $ echo base > base
  $ sl commit -Aqm base
  $ echo 1 > file
  $ sl commit -Aqm commit1
  $ sl book master

  $ newclientrepo client1 server
  $ newclientrepo client2 server
  $ cd ../client1

Attempt to push a public commit to a scratch bookmark.  There is no scratch
data to push, but the bookmark should be accepted.

  $ sl push -q --to scratch/public --create -r . --traceback

Pull this bookmark in the other client
  $ cd ../client2
  $ sl up -q scratch/public
  $ sl log -r . -T '{node|short} "{desc}" {remotebookmarks}\n'
  e6c779c67aa9 "commit1" remote/master remote/scratch/public
  $ cd ../client1

Attempt to push a public commit to a real remote bookmark.  This should also
be accepted.

  $ sl push -q --to real-public --create -r .

Attempt to push a draft commit to a scratch bookmark.  This should still work.

  $ echo 2 > file
  $ sl commit -Aqm commit2
  $ sl push -q --to scratch/draft --create -r .

Check the server data is correct.

  $ sl bookmarks --cwd $TESTTMP/server
   * master                    e6c779c67aa9
     real-public               e6c779c67aa9
     scratch/draft             3f2e32144a89
     scratch/public            e6c779c67aa9

Make another public scratch bookmark on an older commit.

  $ sl up -q 'desc(base)'
  $ sl push -q --to scratch/other --create -r .

Make a new draft commit here, and push it to the other scratch bookmark.  This
works because the old commit is an ancestor of the new commit.

  $ echo a > other
  $ sl commit -Aqm other1
  $ sl push -q --to scratch/other -r . --force

  $ sl -R ../server book
   * master                    e6c779c67aa9
     real-public               e6c779c67aa9
     scratch/draft             3f2e32144a89
     scratch/other             8bebbb8c3ae7
     scratch/public            e6c779c67aa9

Try again with --non-forward-move.

  $ sl push -q --to scratch/public --force -r .

  $ sl -R ../server book
   * master                    e6c779c67aa9
     real-public               e6c779c67aa9
     scratch/draft             3f2e32144a89
     scratch/other             8bebbb8c3ae7
     scratch/public            8bebbb8c3ae7

Move the two bookmarks back to a public commit.

  $ sl push -q --to scratch/public --force -r 'desc(base)'
  $ sl push -q --to scratch/other --force -r 'desc(commit1)'

Update the public scratch bookmarks in the other client, using both -r and -B.

  $ cd ../client2
  $ sl log -r scratch/public -T '{node|short} "{desc}" {remotebookmarks}\n'
  e6c779c67aa9 "commit1" remote/master remote/scratch/public
  $ sl pull -qB scratch/public
  $ sl log -r scratch/public -T '{node|short} "{desc}" {remotebookmarks}\n'
  d20a80d4def3 "base" remote/scratch/public
  $ sl pull -qB scratch/other
  $ sl log -r scratch/other -T '{node|short} "{desc}" {remotebookmarks}\n'
  e6c779c67aa9 "commit1" remote/master remote/scratch/other
