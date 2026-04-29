# Common Mistakes When Writing Hooks

- Forgetting `mod hook_name;` in `implementations.rs`
- Adding match arm without the `mod` line
- Em dashes or curly quotes in commit messages (use `--` and straight quotes)
- Walking the manifest for directories not touched by the changeset
- Missing `ADDITIONAL_DERIVED_DATA` in integration test
- Forgetting to update both `Cargo.toml` and `public_autocargo/.../Cargo.toml`
- Adding deps in BUCK but not in sorted order
