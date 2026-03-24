# Feature: Commit Query Operations
> Depends on: none

## Summary
Implement commit retrieval and history traversal: fetching individual commits, batch commit fetching, log queries with filtering, and linear history traversal (get_commits_between).

## Requirements
- get_commit_v2: Fetch a single commit with optional changed files/dirs
- get_commits_v2: Batch fetch multiple commits
- log_v2: Query commit history with path filtering, date ranges, pagination
- get_commits_between: Linear ancestor traversal between two revisions
- get_commits_between_on_path: Same but filtered by changed paths
- last_commit_on_path: Most recent commit touching a given path
- commit_exists: Check if a commit hash exists

## API Changes
Implements from ScmQueryService:
- `get_commit`, `get_commit_v2`, `get_commits`, `get_commits_v2`
- `log`, `log_v2`
- `get_commits_between`, `get_commits_between_on_path`
- `last_commit_on_path`, `commit_exists`

## Affected Components
- **thrift_handler**: Method implementations
- **core**: Commit resolution, history traversal, ScmCommit construction from Mononoke ChangesetContext

## Acceptance Criteria
- [ ] get_commit_v2 returns correct ScmCommit with all requested optional fields
- [ ] log_v2 respects all filter params (paths, dates, skip, limit, descendants_of_excluding)
- [ ] get_commits_between follows first-parent lineage correctly
- [ ] Deprecated methods delegate to v2 equivalents
- [ ] ScmCommitProp flags correctly control which optional data is fetched

## Out of Scope
- Infinitepush-specific log/bookmarks (separate feature)
