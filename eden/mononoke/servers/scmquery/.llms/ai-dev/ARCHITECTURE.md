# Architecture: ScmQuery Mononoke Service

## System Purpose
ScmQuery is a Thrift service that provides a unified API for querying source control repositories. It supports operations like reading file contents, querying commit history, computing diffs, and looking up repository metadata.

## Tech Stack
- Language: Rust
- Build system: Buck
- Framework: Mononoke server infrastructure (fb303, ServiceFramework)
- Backend: Mononoke APIs (RepoContext, ChangesetContext, etc.)

## Components

### thrift_handler
- **Responsibility**: Implements the ScmQueryService and ScmWriteService thrift interfaces. Receives thrift requests, validates parameters, delegates to the core query logic.
- **Dependencies**: core, mononoke_api

### core
- **Responsibility**: Core business logic for all scmquery operations. Translates thrift request types into Mononoke API calls and formats results back into thrift response types.
- **Dependencies**: mononoke_api

### server
- **Responsibility**: Server binary setup — fb303, ServiceFramework, CLI argument parsing, repo factory initialization. Wires the thrift handler to the Mononoke repo context.
- **Dependencies**: thrift_handler, mononoke_app

## Data Flow
1. Client sends thrift request to ScmQueryService
2. thrift_handler validates request params (repo name, scm_type, rev format)
3. thrift_handler calls core module functions
4. core resolves repo → RepoContext, rev → ChangesetContext via Mononoke API
5. core performs the operation (e.g., path lookup, blame, diff)
6. core converts Mononoke types → thrift response types
7. thrift_handler returns response to client

## API Surface
The service implements the ScmQueryService thrift interface (read operations).

Key operation groups:
- **File content**: cat, blame, ls, path_exists
- **Commit queries**: get_commit, log, get_commits_between
- **Diffs**: get_diff, get_metadata_diff, get_changed_files
- **Repo metadata**: get_repos, get_branches, get_tags
- **Revision relationships**: merge_base, is_ancestor, translate_revs, get_mirrored_revs
- **File location**: locate_files, get_all_file_paths

## Constraints & Invariants
- All operations must go through MononokeAPI libraries, not direct database access
- Rate limiting must be respected (RateLimitedException)
- Deprecated methods (get_commit, log, get_commits) should delegate to their v2 equivalents internally
