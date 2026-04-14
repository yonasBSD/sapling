# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test: git rebase predecessor headers survive the full pipeline:
# Meta git client -> git push -> Mononoke git server -> SCS API (commit_git_mutation_history)

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

Create a branch with a feature commit
  $ mgit checkout -qb feature_branch
  $ echo "feature work" > feature.txt
  $ mgit add feature.txt
  $ mgit commit -qam "feature commit"
  $ FEATURE_ORIG=$(mgit rev-parse HEAD)

Add a commit on master to create divergence
  $ mgit checkout -q master_bookmark
  $ echo "master update" > master.txt
  $ mgit add master.txt
  $ mgit commit -qam "master update"

Rebase feature onto master
  $ mgit checkout -q feature_branch
  $ mgit rebase master_bookmark
  Rebasing (1/1)* (glob)
  Successfully rebased and updated refs/heads/feature_branch.
  $ FEATURE_REBASED=$(mgit rev-parse HEAD)

Verify predecessor headers locally
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$FEATURE_ORIG" && echo "local predecessor matches original"
  local predecessor matches original
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op rebase

Push and verify via commit_git_mutation_history SCS endpoint
  $ quiet git_client push origin master_bookmark feature_branch --force
  $ scs_mutation "$FEATURE_REBASED" | grep "predecessors:" | grep -q "$FEATURE_ORIG" && echo "predecessor matches original feature commit"
  predecessor matches original feature commit
  $ scs_mutation "$FEATURE_REBASED" | grep "op:"
  op: rebase

-- Multi-commit stack rebase: each commit tracks its own predecessor --

  $ mgit checkout -q master_bookmark
  $ mgit checkout -qb stack_branch
  $ echo "stack1" > stack1.txt
  $ mgit add stack1.txt
  $ mgit commit -qam "stack commit 1"
  $ STACK1_ORIG=$(mgit rev-parse HEAD)
  $ echo "stack2" > stack2.txt
  $ mgit add stack2.txt
  $ mgit commit -qam "stack commit 2"
  $ STACK2_ORIG=$(mgit rev-parse HEAD)

Create divergence on master
  $ mgit checkout -q master_bookmark
  $ echo "more master" > master2.txt
  $ mgit add master2.txt
  $ mgit commit -qam "master divergence"

Rebase the 2-commit stack
  $ mgit checkout -q stack_branch
  $ mgit rebase master_bookmark
  Rebasing (1/2)* (glob)
  Rebasing (2/2)* (glob)
  Successfully rebased and updated refs/heads/stack_branch.
  $ STACK2_REBASED=$(mgit rev-parse HEAD)
  $ STACK1_REBASED=$(mgit rev-parse HEAD^)

Verify each commit in the stack has its own predecessor
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$STACK2_ORIG" && echo "top commit predecessor matches"
  top commit predecessor matches
  $ mgit cat-file -p HEAD^ | grep "^predecessor " | grep -q "$STACK1_ORIG" && echo "bottom commit predecessor matches"
  bottom commit predecessor matches

Push and verify both via SCS
  $ quiet git_client push origin master_bookmark stack_branch --force
  $ scs_mutation "$STACK2_REBASED" | grep "predecessors:" | grep -q "$STACK2_ORIG" && echo "SCS: top commit predecessor matches"
  SCS: top commit predecessor matches
  $ scs_mutation "$STACK2_REBASED" | grep "op:"
  op: rebase
  $ scs_mutation "$STACK1_REBASED" | grep "predecessors:" | grep -q "$STACK1_ORIG" && echo "SCS: bottom commit predecessor matches"
  SCS: bottom commit predecessor matches
  $ scs_mutation "$STACK1_REBASED" | grep "op:"
  op: rebase
