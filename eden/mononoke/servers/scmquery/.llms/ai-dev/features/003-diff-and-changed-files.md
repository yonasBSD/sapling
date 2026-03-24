# Feature: Diff and Changed Files
> Depends on: none

## Summary
Implement diff computation and changed file listing between revisions.

## Requirements
- get_diff: Raw unified diff between two revisions
- get_metadata_diff: Structured metadata about changed files (type, size, lines changed)
- get_changed_files: List of changed files with status (added/modified/deleted/moved)
- get_changed_paths_approx: Approximate changed paths from Bonsai (cheaper than full diff)

## API Changes
Implements from ScmQueryService:
- `get_diff`, `get_metadata_diff`
- `get_changed_files`
- `get_changed_paths_approx`

## Affected Components
- **thrift_handler**: Method implementations
- **core**: Diff computation via Mononoke's diff APIs, copy/rename detection

## Acceptance Criteria
- [ ] get_diff returns correct unified diff output
- [ ] get_metadata_diff includes accurate line counts and file type info
- [ ] get_changed_files detects copies/renames when flag is set
- [ ] get_changed_paths_approx returns reasonable approximation

## Out of Scope
- Infinitepush diff methods
