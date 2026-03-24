# Feature: Repository Metadata
> Depends on: none

## Summary
Implement repository-level metadata queries: listing available repos, branches, and tags.

## Requirements
- get_repos: List all available hg and git repositories
- get_branches: Return branch name → commit hash mapping
- get_tags/get_tags_compact: Return tag information

## API Changes
Implements from ScmQueryService:
- `get_repos`
- `get_branches`
- `get_tags`, `get_tags_compact`

## Affected Components
- **thrift_handler**: Method implementations
- **core**: Repo enumeration, bookmark/tag listing via Mononoke API

## Acceptance Criteria
- [ ] get_repos returns correct list of configured repositories
- [ ] get_branches returns all bookmarks as branch→hash map
- [ ] get_tags returns tag info including tagger and message

## Out of Scope
- Tag creation/deletion
- Branch creation
