---
oncalls: ['scm_server_infra']
apply_to_regex: 'eden/mononoke/.*\.rs$'
apply_to_content: 'commit|branch|ref[^a-z]|tree[^_a-z]|commit.hash|commit.id'
---

# Mononoke Domain Naming Conventions

**Severity: HIGH**

## What to Look For

- Use of "commit" instead of "changeset" in Rust identifiers, comments, and doc strings
- Use of "branch" or "ref" instead of "bookmark"
- Use of "commit hash" or "commit id" instead of "changeset_id" / `cs_id`
- Confusion between Bonsai and Hg changeset ID variable names
- Use of "tree" instead of "manifest" for Mononoke-internal tree representations

## When to Flag

- A new or modified identifier, variable, type, function, comment, or doc string uses "commit" where "changeset" is the correct Mononoke term (e.g., `commit_id`, `get_commit`, `// fetch the commit`)
- A new or modified identifier uses "branch" or "ref" where "bookmark" is the correct Mononoke term (e.g., `branch_name`, `resolve_ref`)
- A variable holding a `ChangesetId` (Bonsai) is named with an `hg` prefix, or a variable holding an `HgChangesetId` lacks a distinguishing `hg` prefix
- A new identifier refers to a Mononoke manifest object as a "tree" (e.g., `tree_id`, `fetch_tree`)
- A field or variable is named `commit_hash` or `commit_id` instead of `changeset_id` or `cs_id`

## Do NOT Flag

- Code in the **SCS Thrift server** (`servers/scs/`) that uses "commit" because the SCS API uses that term in its Thrift interface
- Code in the **Git server** (`servers/git/`) that uses "commit", "ref", "branch", or "tree" because these are Git protocol terms
- User-facing error messages, log lines, or CLI help text where "commit" is clearer for end users
- String literals that are part of a wire protocol, serialization format, or external API contract
- Existing code that is not being modified in the current change
- The word "commit" used as a verb (e.g., "commit the transaction")

## Examples

**BAD (using "commit" internally):**
```rust
/// Fetch a commit by its hash.
fn get_commit(ctx: &CoreContext, commit_hash: ChangesetId) -> Result<BonsaiChangeset> {
```

**GOOD (using "changeset"):**
```rust
/// Fetch a changeset by its id.
fn get_changeset(ctx: &CoreContext, cs_id: ChangesetId) -> Result<BonsaiChangeset> {
```

**BAD (using "branch"):**
```rust
fn resolve_branch(repo: &RepoContext, branch_name: &str) -> Result<ChangesetId> {
```

**GOOD (using "bookmark"):**
```rust
fn resolve_bookmark(repo: &RepoContext, bookmark: &BookmarkKey) -> Result<ChangesetId> {
```

**BAD (ambiguous changeset ID naming):**
```rust
let id = repo.get_hg_changeset_id(cs_id).await?;      // `id` is ambiguous
let cs_id = mapping.get_hg_from_bonsai(bcs_id).await?; // `cs_id` for Hg is confusing
```

**GOOD (distinguished Bonsai vs Hg):**
```rust
let hg_cs_id = repo.get_hg_changeset_id(bcs_id).await?;  // clear prefix
let bcs_id = mapping.get_bonsai_from_hg(hg_cs_id).await?; // bcs for Bonsai
```

**BAD (using "tree" for manifests):**
```rust
fn fetch_tree(ctx: &CoreContext, tree_id: MPathHash) -> Result<TreeManifest> {
```

**GOOD (using "manifest"):**
```rust
fn fetch_manifest(ctx: &CoreContext, manifest_id: ManifestId) -> Result<TreeManifest> {
```

## Recommendation

Mononoke uses domain-specific terminology that differs from user-facing Git/Mercurial vocabulary. Internally, always use "changeset" (not "commit"), "bookmark" (not "branch"/"ref"), "changeset_id" or `cs_id` (not "commit hash"/"commit id"), and "manifest" (not "tree"). Distinguish Bonsai changeset IDs (`bcs_id`) from Mercurial ones (`hg_cs_id`). These conventions do not apply to protocol-specific code (Git server, SCS Thrift API) where external terminology is appropriate, nor to user-facing messages where "commit" is standard.
