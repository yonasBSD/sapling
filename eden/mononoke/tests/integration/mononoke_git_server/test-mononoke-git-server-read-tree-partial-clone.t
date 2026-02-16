# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Test that `git read-tree --reset -u HEAD` works correctly after a
# --filter=blob:none partial clone from Mononoke Git server.  This validates
# the lazy blob fetch path that promisor remotes rely on.

  $ . "${TEST_FIXTURES}/library.sh"
  $ REPOTYPE="blob_files"
  $ setup_common_config $REPOTYPE
  $ GIT_REPO_ORIGIN="${TESTTMP}/origin/repo-git"
  $ GIT_REPO="${TESTTMP}/repo-git"

# Setup git repository with files at multiple directory levels
  $ mkdir -p "$GIT_REPO_ORIGIN"
  $ cd "$GIT_REPO_ORIGIN"
  $ git init -q
  $ echo "this is the root README file" > README.md
  $ echo "this is a license file for the project" > LICENSE
  $ git add .
  $ git commit -qam "Initial commit with root files"

  $ mkdir -p src/lib
  $ echo "fn main() { println!(\"hello\"); }" > src/main.rs
  $ echo "pub fn helper() -> bool { true }" > src/lib/helpers.rs
  $ git add .
  $ git commit -qam "Add source files"

  $ mkdir -p docs
  $ echo "this is the documentation index" > docs/index.md
  $ echo "this is the API reference guide" > docs/api.md
  $ git add .
  $ git commit -qam "Add documentation"

# Import it into Mononoke
  $ cd "$TESTTMP"
  $ quiet gitimport "$GIT_REPO_ORIGIN" --derive-hg --generate-bookmarks full-repo

# Start up the Mononoke Git Service
  $ mononoke_git_service

# --- Test 1: Baseline with file:// origin ---
# Clone with filter from the origin to establish expected behavior
  $ cd "$TESTTMP"
  $ git clone --filter=blob:none --no-checkout file://"$GIT_REPO_ORIGIN" "$GIT_REPO"
  Cloning into '$TESTTMP/repo-git'...

# Use read-tree to populate the working tree (triggers lazy blob fetch from file:// origin)
  $ cd "$GIT_REPO"
  $ git read-tree --reset -u HEAD

# Count the files materialized on disk
  $ find . -path "./.git" -prune -o -type f -print | sort
  ./LICENSE
  ./README.md
  ./docs/api.md
  ./docs/index.md
  ./src/lib/helpers.rs
  ./src/main.rs

# Verify file content
  $ cat README.md
  this is the root README file
  $ cat src/main.rs
  fn main() { println!("hello"); }
  $ cat docs/api.md
  this is the API reference guide

# --- Test 2: Same flow from Mononoke ---
# Partial clone from Mononoke with blob:none filter
  $ cd "$TESTTMP"
  $ quiet git_client clone $MONONOKE_GIT_SERVICE_BASE_URL/$REPONAME.git --filter=blob:none --no-checkout

# Use read-tree to populate the working tree (triggers lazy blob fetch from Mononoke)
  $ cd "$REPONAME"
  $ git_client read-tree --reset -u HEAD 2>/dev/null

# Verify same files are materialized
  $ find . -path "./.git" -prune -o -type f -print | sort
  ./LICENSE
  ./README.md
  ./docs/api.md
  ./docs/index.md
  ./src/lib/helpers.rs
  ./src/main.rs

# Verify file content matches
  $ cat README.md
  this is the root README file
  $ cat src/main.rs
  fn main() { println!("hello"); }
  $ cat docs/api.md
  this is the API reference guide

# --- Test 3: Fetch new commit and read-tree again ---
# Capture the current HEAD before importing new commits
  $ current_head=$(git rev-parse HEAD)

# Push a new commit to the origin
  $ cd "$GIT_REPO_ORIGIN"
  $ echo "this is a new configuration file" > config.toml
  $ echo "fn main() { println!(\"updated\"); }" > src/main.rs
  $ git add .
  $ git commit -qam "Add config and update main"

# Import the new commit into Mononoke
  $ cd "$TESTTMP"
  $ quiet gitimport "$GIT_REPO_ORIGIN" --derive-hg --generate-bookmarks full-repo

# Wait for the warm bookmark cache to catch up with the latest changes
  $ cd "$TESTTMP/$REPONAME"
  $ wait_for_git_bookmark_move HEAD $current_head

# Fetch the new commit from Mononoke in the partial clone
  $ git_client fetch origin 2>/dev/null
  $ git log --oneline origin/master_bookmark -1
  * Add config and update main (glob)

# Read-tree the fetched commit to trigger lazy fetch for new/updated blobs
  $ git_client read-tree --reset -u origin/master_bookmark 2>/dev/null

# Verify the updated files are present
  $ find . -path "./.git" -prune -o -type f -print | sort
  ./LICENSE
  ./README.md
  ./config.toml
  ./docs/api.md
  ./docs/index.md
  ./src/lib/helpers.rs
  ./src/main.rs

# Verify new and updated content
  $ cat config.toml
  this is a new configuration file
  $ cat src/main.rs
  fn main() { println!("updated"); }

# Verify unchanged files are still correct
  $ cat docs/index.md
  this is the documentation index
