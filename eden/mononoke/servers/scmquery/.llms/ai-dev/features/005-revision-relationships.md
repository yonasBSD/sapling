# Feature: Revision Relationships
> Depends on: none

## Summary
Implement revision relationship queries: merge base computation, ancestry checks, cross-repo revision translation, and commit indexing.

## Requirements
- merge_base: Find common ancestor of two revisions
- is_ancestor: Check if one revision is ancestor of another
- translate_revs: Translate between revision types (hg hash, globalrev, etc.)
- get_mirrored_revs: Find corresponding commits across mirrored repos
- get_index: Get sequential index for a revision
- get_generation: Get DAG generation number
- get_names_containing_rev_v2: Find bookmarks/branches containing a revision

## API Changes
Implements from ScmQueryService:
- `merge_base`, `is_ancestor`
- `translate_revs`, `get_mirrored_revs`
- `get_index`, `get_generation`
- `get_names_containing_rev_v2`

## Affected Components
- **thrift_handler**: Method implementations
- **core**: Mononoke changeset ancestry APIs, cross-repo syncing APIs

## Acceptance Criteria
- [ ] merge_base returns correct LCA
- [ ] is_ancestor correctly determines ancestry
- [ ] translate_revs handles hg↔globalrev translations
- [ ] get_mirrored_revs works across synced repo pairs

## Out of Scope
- Setting up new repo sync configurations
