# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

  $ cat >> $HGRCPATH <<EOF
  > [extensions]
  > rebase=
  > pushrebase=
  > EOF

setup configuration

  $ REPOTYPE="blob_files"
  $ REPOID=0 REPONAME=meg setup_common_config $REPOTYPE
  $ REPOID=1 REPONAME=with_merge setup_common_config $REPOTYPE
  $ REPOID=2 REPONAME=another setup_common_config $REPOTYPE
  $ setup_commitsyncmap
  $ setup_configerator_configs
  $ setconfig remotenames.selectivepulldefault=master_bookmark,with_merge_master,with_merge_pre_big_merge,merge_with_preserved,another_master

setup repos using testtool_drawdag
  $ testtool_drawdag -R with_merge --no-default-files --derive-all <<'EOF'
  > WM_C1-WM_C2
  > # modify: WM_C1 "somefilebeforemerge" "1\n"
  > # message: WM_C1 "first commit in small repo with merge"
  > # modify: WM_C2 "someotherfilebeforemerge" "2\n"
  > # message: WM_C2 "commit, supposed to be preserved"
  > # bookmark: WM_C1 with_merge_master
  > # bookmark: WM_C2 with_merge_pre_big_merge
  > EOF
  WM_C1=* (glob)
  WM_C2=* (glob)

  $ testtool_drawdag -R another --no-default-files --derive-all <<'EOF'
  > AN_C1
  > # modify: AN_C1 "file.txt" "1\n"
  > # message: AN_C1 "first commit in another small repo"
  > # bookmark: AN_C1 another_master
  > EOF
  AN_C1=* (glob)

  $ testtool_drawdag -R meg --no-default-files --derive-all <<'EOF'
  > MEG_WM1-MEG_WM2
  > MEG_AN1
  > # modify: MEG_WM1 "somefilebeforemerge" "1\n"
  > # message: MEG_WM1 "first commit in small repo with merge"
  > # modify: MEG_WM2 "someotherfilebeforemerge" "2\n"
  > # message: MEG_WM2 "commit, supposed to be preserved"
  > # modify: MEG_AN1 "file.txt" "1\n"
  > # message: MEG_AN1 "first commit in another small repo"
  > # bookmark: MEG_WM1 with_merge_master
  > # bookmark: MEG_WM2 with_merge_pre_big_merge
  > # bookmark: MEG_AN1 another_master
  > EOF
  MEG_AN1=* (glob)
  MEG_WM1=* (glob)
  MEG_WM2=* (glob)

  $ export COMMIT_DATE="1985-09-04T00:00:00.00Z"
move things in small repo with merge
  $ quiet mononoke_admin megarepo move-commit --repo-id 0 --source-repo-id 1 \
  > -B with_merge_master -a user -m "with merge move" --mark-public \
  > --commit-date-rfc3339 "$COMMIT_DATE" --set-bookmark with_merge_move \
  > --mapping-version-name TEST_VERSION_NAME

move things in another small repo
  $ quiet mononoke_admin megarepo move-commit --repo-id 0 --source-repo-id 2 \
  > -B another_master -a user -m "another move" --mark-public \
  > --commit-date-rfc3339 "$COMMIT_DATE" --set-bookmark another_move \
  > --mapping-version-name TEST_VERSION_NAME

merge things in both repos
  $ mononoke_admin megarepo merge --repo-id 0 -B with_merge_move -B another_move -a user \
  > -m "megarepo merge" --mark-public --commit-date-rfc3339 "$COMMIT_DATE" \
  > --set-bookmark master_bookmark &> /dev/null

start mononoke server
  $ start_and_wait_for_mononoke_server

Setup client repos
  $ cd "$TESTTMP"
  $ hg clone -q mono:with_merge with_merge_hg --noupdate
  $ hg clone -q mono:another another_hg --noupdate
  $ hg clone -q mono:meg meg_hg --noupdate

Record current master and the first commit in the preserved stack
  $ WITH_MERGE_PRE_MERGE_PRESERVED=$(mononoke_admin bookmarks --repo-id 1 get with_merge_pre_big_merge)
  $ WITH_MERGE_C1=$(mononoke_admin bookmarks --repo-id 1 get with_merge_master)

Create marker commits, so that we don't have to add $WITH_MERGE_C1 and $MEGAREPO_MERGE to the mapping
(as it's not correct: $WITH_MERGE_C1 is supposed to be preserved)
  $ cd "$TESTTMP/with_merge_hg"
  $ hg pull -q
  $ hg up -q with_merge_master
  $ hg ci -m "marker commit" --config ui.allowemptycommit=True
  $ hg push -r . --to with_merge_master -q
  $ WITH_MERGE_MARKER=$(mononoke_admin bookmarks --repo-id 1 get with_merge_master)

  $ cd "$TESTTMP/meg_hg"
  $ hg pull -q
  $ hg up -q master_bookmark
  $ hg ci -m "marker commit" --config ui.allowemptycommit=True
  $ hg push -r . --to master_bookmark -q
  $ MEGAREPO_MARKER=$(mononoke_admin bookmarks --repo-id 0 get master_bookmark)

insert sync mapping entry
  $ ANOTHER_C1=$(mononoke_admin bookmarks --repo-id 2 get another_master)
  $ MEGAREPO_MERGE=$(mononoke_admin bookmarks --repo-id 0 get master_bookmark)
  $ add_synced_commit_mapping_entry 2 $ANOTHER_C1 0 $MEGAREPO_MERGE TEST_VERSION_NAME
  $ add_synced_commit_mapping_entry 1 $WITH_MERGE_MARKER 0 $MEGAREPO_MARKER TEST_VERSION_NAME

Preserve commits from with_merge
  $ add_synced_commit_mapping_entry 1 $WM_C1 0 $MEG_WM1 TEST_VERSION_NAME
  $ add_synced_commit_mapping_entry 1 $WM_C2 0 $MEG_WM2 TEST_VERSION_NAME

Do a test pull
  $ cd "$TESTTMP"/meg_hg
  $ hg pull -q
  $ hg up -q master_bookmark
  $ ls
  arvr-legacy
  somefilebeforemerge
  $ ls arvr-legacy
  file.txt

Create a branch merge in a small repo
  $ cd "$TESTTMP"/with_merge_hg
  $ drawdag <<'EOF'
  >   D
  >   |\
  >   | C
  >   | |
  >   Y B
  >   |/
  >   A
  > EOF
  $ hg rebase -s $A -d with_merge_master -q
  $ REBASED_A=$(hg log -r "desc('re:^A$') and descendants(desc('marker commit'))" -T '{node|short}')
  $ REBASED_B=$(hg log -r "desc('re:^B$') and descendants(desc('marker commit'))" -T '{node|short}')
  $ REBASED_C=$(hg log -r "desc('re:^C$') and descendants(desc('marker commit'))" -T '{node|short}')
  $ REBASED_Y=$(hg log -r "desc('re:^Y$') and descendants(desc('marker commit'))" -T '{node|short}')
  $ REBASED_D=$(hg log -r "desc('re:^D$') and descendants(desc('marker commit'))" -T '{node|short}')

  $ cd "$TESTTMP"/with_merge_hg
  $ hg up -q tip
  $ ls -R
  .:
  A
  B
  C
  Y
  somefilebeforemerge

Push a single premerge commit and sync it to megarepo
  $ hg push -r $REBASED_A --to with_merge_master -q
  $ mononoke_x_repo_sync 1 0 once --target-bookmark master_bookmark -B with_merge_master  &> /dev/null

Push a commit from another small repo that modifies existing file
  $ cd "$TESTTMP"/another_hg
  $ hg up -q another_master
  $ echo 2 > file.txt
  $ hg ci -m 'modify file.txt'
  $ hg push -r . --to another_master -q

  $ mononoke_x_repo_sync 2 0 once --target-bookmark master_bookmark -B another_master  &> /dev/null

  $ cd "$TESTTMP"/with_merge_hg
Push and sync commits before a diamond commit
  $ hg push -r $REBASED_B --to with_merge_master -q
  $ mononoke_x_repo_sync 1 0 once --target-bookmark master_bookmark -B with_merge_master  &> /dev/null
  $ hg push -r $REBASED_C --to with_merge_master -q
  $ mononoke_x_repo_sync 1 0 once --target-bookmark master_bookmark -B with_merge_master  &> /dev/null

Push one more commit from another small repo
  $ cd "$TESTTMP"/another_hg
  $ hg up -q another_master
  $ echo 3 > file.txt
  $ hg ci -m 'second modification of file.txt'
  $ hg push -r . --to another_master -q

  $ mononoke_x_repo_sync 2 0 once --target-bookmark master_bookmark -B another_master  &> /dev/null

Push diamond commit
  $ cd "$TESTTMP"/with_merge_hg
  $ hg push -r $REBASED_D --to with_merge_master -q &> /dev/null

Try to sync it automatically, it's expected to fail
  $ mononoke_x_repo_sync 1 0 once --target-bookmark master_bookmark -B with_merge_master 2>&1 | grep 'unsupported merge'
  * unsupported merge - only merges of new repos are supported (glob)

Now sync with the tool
  $ cd "$TESTTMP"

  $ mononoke_admin megarepo sync-diamond-merge --bookmark with_merge_master --source-repo-id 1 --target-repo-id 0 --onto-bookmark master_bookmark |& grep -v "using repo"
  * changeset resolved as: ChangesetId(Blake2(*)) (glob)
  * Preparing to sync a merge commit *... (glob)
  * 1 new commits are going to be merged in (glob)
  * syncing commit from new branch * (glob)
  * uploading merge commit * (glob)
  * It is recommended to run 'mononoke_admin cross-repo verify-working-copy' for *! (glob)
-- a mapping should've been created for the synced merge commit
  $ mononoke_admin cross-repo --source-repo-id 0 --target-repo-id 1 map -B master_bookmark |& grep -v "using repo"
  RewrittenAs([(ChangesetId(Blake2(*)), CommitSyncConfigVersion("TEST_VERSION_NAME"))]) (glob)
  $ flush_mononoke_bookmarks


Pull from megarepo
  $ cd "$TESTTMP"/meg_hg
  $ hg pull -q
  $ hg up -q master_bookmark
  $ ls -R
  .:
  A
  B
  C
  Y
  arvr-legacy
  somefilebeforemerge
  
  ./arvr-legacy:
  file.txt



  $ cat arvr-legacy/file.txt
  3

Make sure that we have correct parents
  $ hg log -r 'parents(master_bookmark)' -T '{node} {desc}\n'
  * Y (glob)
  * second modification of file.txt (glob)

Merge with preserved ancestors
  $ cd "$TESTTMP"/with_merge_hg

-- check the mapping for p2's parent
  $ mononoke_admin cross-repo --source-repo-id 1 --target-repo-id 0 map -i $(hg log -T "{node}" -r with_merge_pre_big_merge)
  RewrittenAs([(ChangesetId(Blake2(*)), CommitSyncConfigVersion("TEST_VERSION_NAME"))]) (glob)

-- create a p2, based on a pre-merge commit
  $ hg up with_merge_pre_big_merge -q
  $ echo preserved_pre_big_merge_file > preserved_pre_big_merge_file
  $ hg ci -Aqm "preserved_pre_big_merge_file"
  $ hg book -r . pre_merge_p2

-- create a p1, based on a master
  $ hg up with_merge_master -q
  $ echo ababagalamaga > ababagalamaga
  $ hg ci -Aqm "ababagalamaga"
  $ hg book -r . pre_merge_p1

-- create a merge commit
  $ hg merge pre_merge_p2 -q
  $ hg ci -qm "merge with preserved p2"
  $ hg log -r . -T "{node} {desc}\np1: {p1node}\np2: {p2node}\n"
  * merge with preserved p2 (glob)
  p1: * (glob)
  p2: * (glob)
  $ hg book -r . merge_with_preserved

-- push these folks to the server-side repo
  $ hg push --to with_merge_master 2>&1 | grep updating
  updating bookmark with_merge_master

-- sync p1
  $ cd "$TESTTMP"
  $ mononoke_x_repo_sync 1 0 once --target-bookmark master_bookmark --commit-id $(hg log -T "{node}" -r pre_merge_p1 --cwd "$TESTTMP/with_merge_hg") |& grep -v "using repo"
  * Starting session with id * (glob)
  * Starting up X Repo Sync from small repo with_merge to large repo meg (glob)
  * Syncing 1 commits and all of their unsynced ancestors (glob)
  * Checking if * is already synced 1->0 (glob)
  * 1 unsynced ancestors of * (glob)
  * syncing * via pushrebase for master_bookmark (glob)
  * changeset * synced as * in * (glob)
  * successful sync (glob)
  * X Repo Sync execution finished from small repo with_merge to large repo meg (glob)

-- sync the merge
  $ cd "$TESTTMP"
  $ mononoke_admin megarepo sync-diamond-merge --bookmark with_merge_master --source-repo-id 1 --target-repo-id 0 --onto-bookmark master_bookmark
  * using repo "with_merge" repoid RepositoryId(1) (glob)
  * using repo "meg" repoid RepositoryId(0) (glob)
  * changeset resolved as: ChangesetId(Blake2(*)) (glob)
  * Preparing to sync a merge commit *... (glob)
  * 2 new commits are going to be merged in (glob)
  * syncing commit from new branch * (glob)
  * syncing commit from new branch * (glob)
  * uploading merge commit * (glob)
  * It is recommended to run 'mononoke_admin cross-repo verify-working-copy' for *! (glob)

-- check that p2 was synced as preserved (note identical hashes)
  $ mononoke_admin cross-repo --source-repo-id 1 --target-repo-id 0 map -i $(hg log -r pre_merge_p2 -T "{node}" --cwd "$TESTTMP/with_merge_hg")
  RewrittenAs([(ChangesetId(Blake2(*)), CommitSyncConfigVersion("TEST_VERSION_NAME"))]) (glob)

-- check that merge was synced
  $ mononoke_admin cross-repo --source-repo-id 1 --target-repo-id 0 map -B with_merge_master
  RewrittenAs([(ChangesetId(Blake2(*)), CommitSyncConfigVersion("TEST_VERSION_NAME"))]) (glob)

--verify the working copy
  $ mononoke_admin cross-repo --source-repo-name with_merge --target-repo-name meg verify-working-copy $(mononoke_admin bookmarks -R meg get master_bookmark)
  * target repo cs id: *, mapping version: TEST_VERSION_NAME (glob)
  * ### (glob)
  * ### Checking that all the paths from the repo meg are properly rewritten to with_merge (glob)
  * ### (glob)
  * ### (glob)
  * ### Checking that all the paths from the repo with_merge are properly rewritten to meg (glob)
  * ### (glob)
  * all is well! (glob)
