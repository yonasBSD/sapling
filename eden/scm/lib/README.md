lib
===

Any native code (C/C++/Rust) that Mercurial (either core or extensions)
depends on should go here. Python code, or native code that depends on
Python code (e.g. `#include <Python.h>` or `use cpython`) is disallowed.

As we start to convert more of Mercurial into Rust, and write new paths
entrirely in native code, we'll want to limit our dependency on Python, which is
why this barrier exists.

See also `ext/extlib/README.md`, `mercurial/cext/README.mb`.

How do I choose between `lib` and `extlib` (and `cext`)?
--------------------------------------------------------

If your code is native and doesn't depend on Python (awesome!), it goes here.

Otherwise, put it in `ext/extlib` (if it's only used by extensions) or
`mercurial/cext` (if it's used by extensions or core).

# Sapling Rust Libraries

Rust libraries under `eden/scm/lib/` provide the core logic for Sapling: DAG operations, indexedlog, treestate, types, manifest operations, checkout, and more. These are pure Rust with no Python dependencies.

## Rust Unit Tests

**Location**: Inline in source files (`lib/*/src/*.rs` under `#[cfg(test)] mod tests`) or standalone test files in `lib/*/tests/`.

```bash
buck test fbcode//eden/scm/lib/dag:dag
```

**Tip**: Use `dev_logger::init!()` at the top of a test to enable `RUST_LOG`/`SL_LOG` output — invaluable for debugging test failures.
