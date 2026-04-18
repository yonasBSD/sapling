#require no-eden

  $ configure mutation-norecord
  $ enable rebase amend fbcodereview commitcloud
  $ setconfig experimental.rebaseskipobsolete=true
  $ setconfig extensions.arcconfig="$TESTDIR/../sapling/ext/extlib/phabricator/arcconfig.py"

  $ echo '{}' > $TESTTMP/.arcrc
  $ echo '{"config" : {"default" : "https://a.com/api"}, "hosts" : {"https://a.com/api/" : { "user" : "testuser", "oauth" : "garbage_cert"}}}' > $TESTTMP/.arcconfig

  $ export HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit

  $ landed_graphql() {
  >   printf '{"number": %s, ' $1
  >   printf '"diff_status_name": "Closed",'
  >   printf '"phabricator_versions": { "nodes": [] }, "phabricator_diff_commit": '
  >   printf '{ "nodes": [{"commit_identifier": "%s"}]}}' $2
  > }

  $ commitdrev() {
  >   printf "%s\n\nDifferential Revision: https://phabricator.fb.com/D%s" "$1" "$2" > $TESTTMP/msg
  >   sl commit -ql $TESTTMP/msg
  > }

Set up the server repo

  $ newrepo server
  $ echo base > file
  $ sl commit -Aqm "base"
  $ sl bookmark master
  $ cd ..

Clone the client

  $ sl clone -q test:server client
  $ cd client
  $ cp $TESTTMP/.arcconfig .

Create a draft commit and upload it to the server

  $ echo "draft content" > file
  $ commitdrev "my change" 123
  $ DRAFT=$(sl log -r . -T '{node}')
  $ sl cloud upload -q -r .

Land the draft on the server by rebasing onto master.

  $ cd ../server
  $ sl commit -Aqm "another server commit" --config ui.allowemptycommit=true
  $ sl bookmark -f master
  $ sl rebase -q -r $DRAFT -d master
  $ sl bookmark -f master -r tip
  $ LANDED=$(sl log -r tip -T '{node}')

Add a conflicting commit on the server on top of the landed commit

  $ sl goto -q tip
  $ echo "more server work" > file
  $ sl commit -Aqm "server change"
  $ sl bookmark -f master
  $ cd ../client

  $ printf '[{"data": {"phabricator_diff_query": [{"results": {"nodes": [%s]}}]}}]' \
  > "$(landed_graphql 123 $LANDED)" > $TESTTMP/mockduit

Now pull --rebase. The rebase tries to rebase our draft onto the new master
and conflicts because both sides modified "file".

  $ sl pull -q --rebase 2>&1 | head -20
  warning: 1 conflicts while merging file! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)

  $ sl whereami
  7917f7c71917a0e1384c5dfd50a9e1ffe7fdd764
  37eea62fd2622b7611d523a291874f5bf9d327ae

  $ echo "resolved" > file
  $ sl resolve --mark file
  (no more unresolved files)
  continue: sl rebase --continue

Run debugmarklanded to mark the draft as a predecessor of the landed version.

  $ sl pull -q -r $LANDED

  $ sl rebase --continue
  note: not rebasing 37eea62fd262 "my change", already in destination as ba40b905cc98 "my change"

p2 should be cleared after rebase --continue.

  $ sl whereami
  7917f7c71917a0e1384c5dfd50a9e1ffe7fdd764

A subsequent commit should not be a merge commit.

  $ echo "new work" > newfile
  $ sl commit -Aqm "new work"
  $ sl log -r . -T '{parents}\n'
  7917f7c71917 
