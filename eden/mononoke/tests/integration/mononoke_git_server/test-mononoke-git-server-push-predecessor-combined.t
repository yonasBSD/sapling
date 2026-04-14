# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test: Combined operations — rebase then amend. The final predecessor should
# point to the rebased commit (from amend), not the original (from rebase).
# Also tests that a push with mixed predecessor/non-predecessor commits works.

  $ . "${TEST_FIXTURES}/library.sh"
  $ . "${TEST_FIXTURES}/library-meta-git-predecessor.sh"
  $ REPOTYPE="blob_files"
  $ setup_common_config $REPOTYPE

Start services, clone, and seed with a base commit
  $ mononoke_git_service
  $ set_mononoke_as_source_of_truth_for_git
  $ start_and_wait_for_scs_server
  $ GIT_REPO="${TESTTMP}/repo-git"
  $ quiet git_client clone $MONONOKE_GIT_SERVICE_BASE_URL/$REPONAME.git "$GIT_REPO"
  $ cd "$GIT_REPO"
  $ mgit config commit.recordPredecessor true
  $ echo "base" > file.txt
  $ mgit add file.txt
  $ mgit commit -qam "base commit"
  $ git_client push origin master_bookmark
  To https://*/repos/git/ro/repo.git (glob)
   * [new branch]      master_bookmark -> master_bookmark
  $ wait_for_git_bookmark_create refs/heads/master_bookmark

-- Rebase then amend: predecessor chain is rebase -> amend --

Create a feature branch
  $ mgit checkout -qb feature
  $ echo "feature" > feature.txt
  $ mgit add feature.txt
  $ mgit commit -qam "feature commit"
  $ FEATURE_ORIG=$(mgit rev-parse HEAD)

Create divergence
  $ mgit checkout -q master_bookmark
  $ echo "master change" > master.txt
  $ mgit add master.txt
  $ mgit commit -qam "master change"

Rebase
  $ mgit checkout -q feature
  $ mgit rebase master_bookmark
  Rebasing (1/1)* (glob)
  Successfully rebased and updated refs/heads/feature.
  $ FEATURE_REBASED=$(mgit rev-parse HEAD)

Verify rebase predecessor
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$FEATURE_ORIG" && echo "after rebase: predecessor is original"
  after rebase: predecessor is original
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op rebase

Now amend the rebased commit
  $ echo "amended feature" > feature.txt
  $ mgit commit --amend -qam "amended rebased feature"
  $ FEATURE_AMENDED=$(mgit rev-parse HEAD)

After amend: predecessor should be the rebased commit, not the original
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$FEATURE_REBASED" && echo "after amend: predecessor is rebased commit"
  after amend: predecessor is rebased commit
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$FEATURE_ORIG" && echo "FAIL: predecessor is still original" || echo "original predecessor correctly replaced"
  original predecessor correctly replaced
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op amend

Push and verify via SCS
  $ quiet git_client push origin master_bookmark feature --force
  $ scs_mutation "$FEATURE_AMENDED" | grep "predecessors:" | grep -q "$FEATURE_REBASED" && echo "SCS: predecessor is rebased commit"
  SCS: predecessor is rebased commit
  $ scs_mutation "$FEATURE_AMENDED" | grep "op:"
  op: amend

-- Mixed push: predecessor and non-predecessor commits --

Create a normal commit (no predecessor) alongside the feature branch
  $ mgit checkout -q master_bookmark
  $ echo "normal commit" > normal.txt
  $ mgit add normal.txt
  $ mgit commit -qam "normal commit with no predecessor"
  $ NORMAL=$(mgit rev-parse HEAD)

Push both branches
  $ quiet git_client push origin master_bookmark feature --force

Verify normal commit has no mutation history
  $ scs_mutation "$NORMAL"
  no mutations

Verify feature commit still has mutation history
  $ scs_mutation "$FEATURE_AMENDED" | grep "op:"
  op: amend

-- Message-only amend: no file changes, still tracks predecessor --

  $ mgit checkout -q master_bookmark
  $ echo "msg test" > msgtest.txt
  $ mgit add msgtest.txt
  $ mgit commit -qam "original message"
  $ MSG_ORIG=$(mgit rev-parse HEAD)
  $ mgit commit --amend -qam "improved message"
  $ MSG_AMENDED=$(mgit rev-parse HEAD)

Verify predecessor even though only the message changed
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$MSG_ORIG" && echo "message-only amend has predecessor"
  message-only amend has predecessor
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op amend

Push and verify
  $ quiet git_client push origin master_bookmark --force
  $ scs_mutation "$MSG_AMENDED" | grep "predecessors:" | grep -q "$MSG_ORIG" && echo "SCS: message-only amend predecessor matches"
  SCS: message-only amend predecessor matches

-- Cherry-pick to multiple branches: each target gets its own predecessor --

Create a source commit
  $ mgit checkout -q master_bookmark
  $ echo "shared fix" > shared.txt
  $ mgit add shared.txt
  $ mgit commit -qam "shared fix commit"
  $ SHARED_SOURCE=$(mgit rev-parse HEAD)

Cherry-pick to branch_a (which has its own unique commit)
  $ mgit checkout -qb branch_a HEAD^
  $ echo "branch_a content" > branch_a.txt
  $ mgit add branch_a.txt
  $ mgit commit -qam "branch_a base"
  $ quiet mgit cherry-pick "$SHARED_SOURCE"
  $ CP_BRANCH_A=$(mgit rev-parse HEAD)

Cherry-pick the same commit to branch_b (which also has its own unique commit)
  $ mgit checkout -qb branch_b master_bookmark^
  $ echo "branch_b content" > branch_b.txt
  $ mgit add branch_b.txt
  $ mgit commit -qam "branch_b base"
  $ quiet mgit cherry-pick "$SHARED_SOURCE"
  $ CP_BRANCH_B=$(mgit rev-parse HEAD)

Both cherry-picks should point to the same source but be different commits
(different parents means different hashes)
  $ test "$CP_BRANCH_A" != "$CP_BRANCH_B" && echo "cherry-picks are distinct commits"
  cherry-picks are distinct commits

Verify both locally
  $ mgit cat-file -p "$CP_BRANCH_A" | grep "^predecessor " | grep -q "$SHARED_SOURCE" && echo "branch_a predecessor matches source"
  branch_a predecessor matches source
  $ mgit cat-file -p "$CP_BRANCH_B" | grep "^predecessor " | grep -q "$SHARED_SOURCE" && echo "branch_b predecessor matches source"
  branch_b predecessor matches source

Push all branches and verify via SCS
  $ quiet git_client push origin master_bookmark branch_a branch_b --force
  $ scs_mutation "$CP_BRANCH_A" | grep "predecessors:" | grep -q "$SHARED_SOURCE" && echo "SCS: branch_a predecessor matches"
  SCS: branch_a predecessor matches
  $ scs_mutation "$CP_BRANCH_A" | grep "op:"
  op: cherry-pick
  $ scs_mutation "$CP_BRANCH_B" | grep "predecessors:" | grep -q "$SHARED_SOURCE" && echo "SCS: branch_b predecessor matches"
  SCS: branch_b predecessor matches
  $ scs_mutation "$CP_BRANCH_B" | grep "op:"
  op: cherry-pick

-- Rebase stack then amend top: complex multi-step mutation --

  $ mgit checkout -q master_bookmark
  $ mgit checkout -qb complex_stack
  $ echo "commit 1" > c1.txt
  $ mgit add c1.txt
  $ mgit commit -qam "complex stack commit 1"
  $ C1_ORIG=$(mgit rev-parse HEAD)
  $ echo "commit 2" > c2.txt
  $ mgit add c2.txt
  $ mgit commit -qam "complex stack commit 2"
  $ C2_ORIG=$(mgit rev-parse HEAD)

Advance master
  $ mgit checkout -q master_bookmark
  $ echo "advance" > advance.txt
  $ mgit add advance.txt
  $ mgit commit -qam "advance master"

Rebase the stack
  $ mgit checkout -q complex_stack
  $ mgit rebase master_bookmark
  Rebasing (1/2)* (glob)
  Rebasing (2/2)* (glob)
  Successfully rebased and updated refs/heads/complex_stack.
  $ C2_REBASED=$(mgit rev-parse HEAD)
  $ C1_REBASED=$(mgit rev-parse HEAD^)

Now amend the top commit of the rebased stack
  $ echo "amended c2" > c2.txt
  $ mgit commit --amend -qam "complex stack commit 2 (amended after rebase)"
  $ C2_FINAL=$(mgit rev-parse HEAD)

The final commit's predecessor should be the rebased version (from amend),
not the original (from rebase) — amend replaces rebase's predecessor
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$C2_REBASED" && echo "final predecessor is rebased commit"
  final predecessor is rebased commit
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op amend

The bottom commit should still have rebase predecessor
  $ mgit cat-file -p HEAD^ | grep "^predecessor " | grep -q "$C1_ORIG" && echo "bottom commit predecessor is original"
  bottom commit predecessor is original
  $ mgit cat-file -p HEAD^ | grep "^predecessor-op"
  predecessor-op rebase

Push and verify the full chain via SCS
  $ quiet git_client push origin master_bookmark complex_stack --force
  $ scs_mutation "$C2_FINAL" | grep "predecessors:" | grep -q "$C2_REBASED" && echo "SCS: top commit predecessor is rebased"
  SCS: top commit predecessor is rebased
  $ scs_mutation "$C2_FINAL" | grep "op:"
  op: amend
  $ scs_mutation "$C1_REBASED" | grep "predecessors:" | grep -q "$C1_ORIG" && echo "SCS: bottom commit predecessor is original"
  SCS: bottom commit predecessor is original
  $ scs_mutation "$C1_REBASED" | grep "op:"
  op: rebase
