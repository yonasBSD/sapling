# Feature: File Content Operations
> Depends on: none

## Summary
Implement file content retrieval operations: reading file contents (cat), computing blame/annotation, listing directory contents (ls), and checking path existence.

## Requirements
- cat/cat_v2: Return raw file content at a given revision
- blame/blame_v2: Return per-line annotation with commit info
- ls/ls_v2: List directory entries with type info
- path_exists: Check whether a path exists at a revision

## API Changes
Implements from ScmQueryService:
- `cat`, `cat_v2`
- `blame`, `blame_v2`
- `ls`, `ls_v2`
- `path_exists`

## Affected Components
- **thrift_handler**: Add method implementations for each endpoint
- **core**: Add functions to resolve path → Mononoke PathContext, read content, compute blame

## Acceptance Criteria
- [ ] cat_v2 returns file content matching Mononoke's file_content API
- [ ] blame_v2 returns correct per-line commit attribution
- [ ] ls_v2 returns directory listing with correct ScmFileInfo entries
- [ ] path_exists returns true/false correctly
- [ ] NoSuchPathException thrown for missing paths
- [ ] BadRevException thrown for invalid revisions
- [ ] Legacy cat/blame/ls methods delegate to v2 implementations

## Out of Scope
- LFS content resolution (return LFS pointer as-is)
- Infinitepush-specific paths
