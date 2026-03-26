---
oncalls: ['source_control']
apply_to_regex: 'eden/mononoke/.*\.rs$'
apply_to_content: '\.clone\(\)|\.ok_or\(|\.unwrap_or\(|\.map_err\('
---

# Unnecessary Cloning and Eager Allocation

**Severity: MEDIUM**

## What to Look For

- `.clone()` inside a `for` loop or `.map()` closure where the value could be borrowed or moved; also cloning only to pass to a function that could take a reference
- `.ok_or(format!(...))` or `.ok_or(anyhow!(...))` -- allocates eagerly even on the success path; use `.ok_or_else(|| expr)`
- `.unwrap_or(String::new())` or `.unwrap_or(vec![])` -- allocates even when a value is present; use `.unwrap_or_else(|| expr)`
- `.map_err(SomeError::from)` allocating on the conversion path when `?` with a `From` impl suffices
- Pre-constructing error values passed to `unwrap_or` or `ok_or` (allocation happens even on the success path)
- `if map.contains_key(&k) { ... } else { map.insert(k, v); }` -- double lookup; use `.entry()`

## Do NOT Flag

- `.clone()` required to satisfy ownership (e.g., moving into a `tokio::spawn` closure or `'static` bound)
- `.clone()` on `Arc`, `ChangesetId`, `RepoId`, or other cheap-to-clone types (Copy or pointer-sized)
- `.ok_or(simple_enum_variant)` where the argument is a zero-allocation constant
- `.unwrap_or(0)`, `.unwrap_or(false)`, `.unwrap_or("")` -- trivially cheap defaults
- Test code
- Cases where the clone is needed to avoid holding a borrow across an `.await`

## Examples

**BAD (eager allocation on success path):**
```rust
let name = optional_name.ok_or(format!("name missing for {}", id))?;
```

**GOOD (lazy allocation only on error):**
```rust
let name = optional_name.ok_or_else(|| format!("name missing for {}", id))?;
```

**BAD (clone in loop):**
```rust
for cs_id in &changeset_ids {
    let repo = repo_ctx.clone(); // clones RepoContext every iteration
    let result = process(repo, *cs_id).await?;
    results.push(result);
}
```

**GOOD (borrow or move):**
```rust
for cs_id in &changeset_ids {
    let result = process(&repo_ctx, *cs_id).await?;
    results.push(result);
}
```

**BAD (double lookup):**
```rust
if !seen.contains_key(&path) {
    seen.insert(path.clone(), entry);
}
```

**GOOD (entry API):**
```rust
seen.entry(path).or_insert(entry);
```

**BAD (pre-constructed error):**
```rust
let error = anyhow!("changeset {} not found", cs_id);
let cs = maybe_cs.ok_or(error)?;
// `error` is allocated even when maybe_cs is Some
```

**GOOD (lazy construction):**
```rust
let cs = maybe_cs.ok_or_else(|| anyhow!("changeset {} not found", cs_id))?;
```

## Recommendation

Treat `.clone()` as a code smell in hot paths and loops -- justify each one. Use `.ok_or_else()` and `.unwrap_or_else()` instead of their eager counterparts whenever the fallback expression allocates. Prefer the `HashMap::entry` API over `contains_key` + `insert`. These are small wins individually but compound across the codebase, and more importantly they signal intent: lazy evaluation means the author thought about when allocation happens.

## Evidence

- D38423155: Review comment flagging unnecessary cloning and suggesting `.entry()` API
- D36449077: Review comment on pre-constructing errors passed to `unwrap_or` -- "Rather than constructing the error beforehand (which is an allocation whether it fails or not), you should use a lambda"
