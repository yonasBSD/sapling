# Feature: File Location
> Depends on: none

## Summary
Implement file search/location operations: finding files by basename or suffix, and listing all file paths in a repo.

## Requirements
- locate_files/locate_files_v2: Find files matching basename or suffix patterns
- get_all_file_paths: Return all file paths in a repo (compressed)

## API Changes
Implements from ScmQueryService:
- `locate_files`, `locate_files_v2`
- `get_all_file_paths`

## Affected Components
- **thrift_handler**: Method implementations
- **core**: Mononoke manifest traversal, basename matching, gzip compression

## Acceptance Criteria
- [ ] locate_files_v2 returns correct paths for basename and suffix queries
- [ ] get_all_file_paths returns gzipped null-delimited path list
- [ ] Large repos don't cause OOM (streaming where possible)

## Out of Scope
- Regex-based file search
- Content-based search (grep)
