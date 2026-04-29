# Hook Testing Patterns

## Unit Test Categories

Always include these test categories:
1. **Under limit / valid** -- should accept
2. **Over limit / invalid** -- should reject (assert Accepted in diff 1, Rejected in diff 3)
3. **Edge cases** -- nonexistent prefix, deeply nested files, multiple directories
4. **No short-circuit** -- verify hook runs for `PushAuthoredBy::Service` and `CrossRepoPushSource::PushRedirected` (unless intentionally skipped)

## Unit Test APIs

- `test_repo_factory::build_empty(ctx.fb).await?` -- create empty test repo
- `CreateCommitContext::new_root(ctx, repo).add_file("path", "content").commit().await?` -- create commit
- `cs_id.load(ctx, &repo.repo_blobstore).await?` -- load BonsaiChangeset
- `HookRepo::build_from(&repo)` -- create HookRepo from test repo
- Import `blobstore::Loadable` in test module (needed for `.load()`)

## Integration Test Setup

```
  $ . "${TEST_FIXTURES}/library.sh"

  $ ADDITIONAL_DERIVED_DATA="content_manifests" hook_test_setup \
  > hook_name <(
  >   cat <<CONF
  > config_json='''{
  >   "key": "value"
  > }'''
  > CONF
  > )
```

Only add `ADDITIONAL_DERIVED_DATA` if your hook derives content manifests.

## Expected Output

Accepted push:
```
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  updating bookmark master_bookmark
```

Rejected push:
```
  $ hg push -r . --to master_bookmark
  pushing rev * to destination mono:repo bookmark master_bookmark (glob)
  searching for changes
  remote: Command failed
  remote:   Error:
  remote:     hooks failed:
  remote:     hook_name for *: Your rejection message (glob)
  abort: unexpected EOL, expected netstring digit
  [255]
```
