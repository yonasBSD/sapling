# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test: git commit --amend predecessor headers survive the full pipeline:
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
  $ BASE=$(mgit rev-parse HEAD)
  $ git_client push origin master_bookmark
  To https://*/repos/git/ro/repo.git (glob)
   * [new branch]      master_bookmark -> master_bookmark
  $ wait_for_git_bookmark_create refs/heads/master_bookmark

Verify base commit has no mutation history
  $ scs_mutation "$BASE"
  no mutations

Amend the commit — this triggers predecessor injection
  $ echo "amended content" > file.txt
  $ mgit commit --amend -qam "amended commit"
  $ AMENDED=$(mgit rev-parse HEAD)

Verify predecessor headers locally
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$BASE" && echo "local predecessor matches base"
  local predecessor matches base
  $ mgit cat-file -p HEAD | grep "^predecessor-op"
  predecessor-op amend

Push and verify via commit_git_mutation_history SCS endpoint
  $ quiet git_client push origin master_bookmark --force
  $ scs_mutation "$AMENDED" | grep "predecessors:" | grep -q "$BASE" && echo "predecessor matches base commit"
  predecessor matches base commit
  $ scs_mutation "$AMENDED" | grep "op:"
  op: amend

-- Successive amends: predecessor updates to latest, stale headers stripped --

  $ echo "v2 content" > file.txt
  $ mgit commit --amend -qam "second amend"
  $ AMENDED_V2=$(mgit rev-parse HEAD)

Verify locally that predecessor points to the first amend, not the base
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$AMENDED" && echo "local predecessor matches first amend"
  local predecessor matches first amend

Verify stale predecessor (BASE) is NOT present
  $ mgit cat-file -p HEAD | grep "^predecessor " | grep -q "$BASE" && echo "FAIL: stale predecessor found" || echo "stale predecessor correctly stripped"
  stale predecessor correctly stripped

Push and verify via SCS
  $ quiet git_client push origin master_bookmark --force
  $ scs_mutation "$AMENDED_V2" | grep "predecessors:" | grep -q "$AMENDED" && echo "SCS predecessor matches first amend"
  SCS predecessor matches first amend

-- Amend chain pushed incrementally: A→B (push), B→C (push) --

Start fresh on a new branch to avoid confusion with prior amends
  $ mgit checkout -qb chain_test master_bookmark
  $ echo "chain start" > chain.txt
  $ mgit add chain.txt
  $ mgit commit -qam "chain: version A"
  $ CHAIN_A=$(mgit rev-parse HEAD)

Push A
  $ quiet git_client push origin chain_test --force

Verify A has no predecessor (it's a normal commit)
  $ scs_mutation "$CHAIN_A"
  no mutations

Amend A→B and push
  $ echo "chain v2" > chain.txt
  $ mgit commit --amend -qam "chain: version B"
  $ CHAIN_B=$(mgit rev-parse HEAD)
  $ quiet git_client push origin chain_test --force

Verify B's immediate predecessor is A
  $ scs_mutation "$CHAIN_B" | grep "predecessors:" | grep -q "$CHAIN_A" && echo "B predecessor is A"
  B predecessor is A
  $ scs_mutation "$CHAIN_B" | grep "op:"
  op: amend

Amend B→C and push
  $ echo "chain v3" > chain.txt
  $ mgit commit --amend -qam "chain: version C"
  $ CHAIN_C=$(mgit rev-parse HEAD)
  $ quiet git_client push origin chain_test --force

Verify C's immediate predecessor is B (not A)
  $ scs_mutation "$CHAIN_C" | grep "predecessors:" | grep -q "$CHAIN_B" && echo "C predecessor is B"
  C predecessor is B
  $ scs_mutation "$CHAIN_C" | grep "op:"
  op: amend

Verify A is still queryable and has no predecessor
  $ scs_mutation "$CHAIN_A"
  no mutations

Verify B is still queryable and points to A
  $ scs_mutation "$CHAIN_B" | grep "predecessors:" | grep -q "$CHAIN_A" && echo "B still points to A"
  B still points to A
