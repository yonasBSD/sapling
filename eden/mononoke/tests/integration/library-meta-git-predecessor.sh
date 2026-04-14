#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.


# Shared helpers for predecessor tracking integration tests.
# Source this after library.sh: . "${TEST_FIXTURES}/library-meta-git-predecessor.sh"
#
# Provides:
#   mgit()         — run Meta-built git with correct exec path and identity
#   scs_mutation() — query commit_git_mutation_history SCS endpoint

# Setup Meta git binary with identity env vars matching library.sh's git wrapper
META_GIT="${META_GIT_CLIENT}"
META_GIT_EXEC_PATH="$(dirname "$META_GIT")"

mgit() {
  GIT_EXEC_PATH="$META_GIT_EXEC_PATH" \
  GIT_AUTHOR_NAME="mononoke" \
  GIT_AUTHOR_EMAIL="mononoke@mononoke" \
  GIT_COMMITTER_NAME="mononoke" \
  GIT_COMMITTER_EMAIL="mononoke@mononoke" \
  GIT_AUTHOR_DATE="01/01/0000 00:00 +0000" \
  GIT_COMMITTER_DATE="01/01/0000 00:00 +0000" \
  "$META_GIT" "$@"
}

# Query git mutation history via the commit_git_mutation_history SCS endpoint.
# Usage: scs_mutation <git-sha1>
# Output: "op: <op>\npredecessors: <sha1> ..." for each mutation, or "no mutations"
scs_mutation() {
  scsc git-mutation-history -R repo -i "$1" --json 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
mutations = data.get('mutations', [])
if not mutations:
    print('no mutations')
else:
    for m in mutations:
        print(f'op: {m[\"op\"]}')
        print(f'predecessors: {\" \".join(m[\"predecessors\"])}')
"
}
