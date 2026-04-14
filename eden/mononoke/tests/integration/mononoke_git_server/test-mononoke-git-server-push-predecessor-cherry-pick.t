# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test: git cherry-pick predecessor headers survive the full pipeline:
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

Create a branch with a commit to cherry-pick
  $ mgit checkout -qb source_branch
  $ echo "cherry content" > cherry.txt
  $ mgit add cherry.txt
  $ mgit commit -qam "commit to cherry-pick"
  $ CHERRY_SOURCE=$(mgit rev-parse HEAD)

Cherry-pick onto master
  $ mgit checkout -q master_bookmark
  $ quiet mgit cherry-pick "$CHERRY_SOURCE"
  $ CHERRY_PICKED=$(mgit rev-parse HEAD)

Verify predecessor headers locally
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$CHERRY_SOURCE" && echo "local predecessor matches source"
  local predecessor matches source
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op cherry-pick

Push and verify via commit_git_mutation_history SCS endpoint
  $ quiet git_client push origin master_bookmark --force
  $ scs_mutation "$CHERRY_PICKED" | grep "predecessors:" | grep -q "$CHERRY_SOURCE" && echo "predecessor matches cherry-pick source"
  predecessor matches cherry-pick source
  $ scs_mutation "$CHERRY_PICKED" | grep "op:"
  op: cherry-pick
