
#require eden

  $ export HGIDENTITY=sl
  $ setconfig worktree.enabled=true

setup backing repo

  $ newclientrepo myrepo
  $ touch file.txt
  $ sl add file.txt
  $ sl commit -m "init"

test worktree add - basic

  $ sl worktree add $TESTTMP/linked1
  created linked worktree at $TESTTMP/linked1

test worktree add - with label

  $ sl worktree add $TESTTMP/linked2 --label "feature-x"
  created linked worktree at $TESTTMP/linked2

test worktree add - from a subdirectory of the repo

  $ mkdir -p subdir/nested
  $ cd subdir/nested
  $ sl worktree add $TESTTMP/linked_from_subdir
  created linked worktree at $TESTTMP/linked_from_subdir
  $ cd $TESTTMP/myrepo

test worktree add - missing PATH argument

  $ sl worktree add
  abort: usage: sl worktree add PATH
  [255]

test worktree add - destination exists

  $ mkdir $TESTTMP/existing
  $ sl worktree add $TESTTMP/existing
  abort: destination path '$TESTTMP/existing' already exists
  [255]
  $ rmdir $TESTTMP/existing

test worktree add - linked checkout has same files

  $ ls $TESTTMP/linked1/file.txt
  $TESTTMP/linked1/file.txt

test worktree add - linked checkout is on the same commit as main checkout

  $ main_hash=$(sl log -r . -T '{node}')
  $ linked_hash=$(cd $TESTTMP/linked1 && sl log -r . -T '{node}')
  $ test "$main_hash" = "$linked_hash"
  $ echo "main: $main_hash, linked: $linked_hash"
  main: *, linked: * (glob)

test worktree add - edensparse filters are copied to linked checkout

  $ enable edensparse
  $ cd $TESTTMP
  $ newrepo sparse_server
  $ echo content > included.txt
  $ echo other > excluded.txt
  $ cat > my-filter <<EOF
  > [include]
  > included.txt
  > my-filter
  > [exclude]
  > excluded.txt
  > EOF
  $ sl commit -Aqm 'add files and filter'
  $ sl book master

  $ cd $TESTTMP
  $ sl clone -q --eden test:sparse_server sparse_client --config clone.eden-sparse-filter=my-filter
  $ cd sparse_client

verify main checkout has sparse config

  $ sl filteredfs show
  Enabled Profiles:
  
      ~ my-filter

create linked worktree and verify sparse config is copied

  $ sl worktree add $TESTTMP/sparse_linked
  created linked worktree at $TESTTMP/sparse_linked
  $ cd $TESTTMP/sparse_linked
  $ sl filteredfs show
  Enabled Profiles:
  
      ~ my-filter
  $ cd $TESTTMP/sparse_client

verify both checkouts have the same sparse config content

  $ cmp .sl/sparse $TESTTMP/sparse_linked/.sl/sparse

test worktree add - sl status works in linked filteredfs worktree

FIXME: sl status fails in a freshly created filteredfs worktree because
eden clone is called without --filter-path, writing the SNAPSHOT with a "null"
filter ID. The Rust client then computes a real filter ID from .sl/sparse,
causing a mismatch.

  $ cd $TESTTMP/sparse_client
  $ sl worktree add $TESTTMP/sparse_linked_status
  created linked worktree at $TESTTMP/sparse_linked_status
  $ cd $TESTTMP/sparse_linked_status
  $ sl status
  abort: EdenError: error computing status: requested parent commit is out-of-date: requested *, but current parent commit is *. (glob)
  Try running `eden doctor` to remediate
  [255]

  $ cd $TESTTMP/sparse_client

test worktree add - prefetch profiles are copied to linked checkout

  $ cd $TESTTMP
  $ newrepo prefetch_server
  $ echo content > file.txt
  $ sl commit -Aqm 'add file'
  $ sl book master

  $ cd $TESTTMP
  $ sl clone -q --eden test:prefetch_server prefetch_client
  $ cd prefetch_client

activate a prefetch profile in the main checkout

  $ eden prefetch-profile activate trees
  $ eden prefetch-profile list --checkout .
  trees

create linked worktree and verify prefetch profile is copied

  $ sl worktree add $TESTTMP/prefetch_linked
  created linked worktree at $TESTTMP/prefetch_linked
  $ eden prefetch-profile list --checkout $TESTTMP/prefetch_linked
  trees

test worktree add - redirections are copied to linked checkout

  $ cd $TESTTMP
  $ newrepo redirect_server
  $ echo content > file.txt
  $ sl commit -Aqm 'add file'
  $ sl book master

  $ cd $TESTTMP
  $ sl clone -q --eden test:redirect_server redirect_client
  $ cd redirect_client

add a symlink redirection in the main checkout

  $ mkdir build_output
  $ eden redirect add build_output symlink
  $ eden redirect list --json --mount . | grep -o '"repo_path":"build_output"'
  "repo_path":"build_output"

create linked worktree and verify redirection is copied

  $ sl worktree add $TESTTMP/redirect_linked
  created linked worktree at $TESTTMP/redirect_linked
  $ eden redirect list --json --mount $TESTTMP/redirect_linked | grep -o '"repo_path":"build_output"'
  "repo_path":"build_output"

clean up redirections

  $ eden redirect del build_output
  $ eden redirect del --mount $TESTTMP/redirect_linked build_output

test worktree add - post-worktree-add hook fires with correct env vars

  $ cd $TESTTMP
  $ newclientrepo hook_repo
  $ touch file.txt
  $ sl add file.txt
  $ sl commit -m "init"
#if windows
  $ setconfig hooks.post-worktree-add="echo PATH:%HG_PATH% SOURCE:%HG_SOURCE%"
  $ sl worktree add $TESTTMP/hook_linked
  created linked worktree at $TESTTMP/hook_linked
  PATH:$TESTTMP?hook_linked SOURCE:$TESTTMP?hook_repo\r (esc) (glob)
#else
  $ setconfig hooks.post-worktree-add="echo PATH:\$HG_PATH SOURCE:\$HG_SOURCE"
  $ sl worktree add $TESTTMP/hook_linked
  created linked worktree at $TESTTMP/hook_linked
  PATH:$TESTTMP/hook_linked SOURCE:$TESTTMP/hook_repo
#endif

test worktree add - post-worktree-add hook failure does not abort command

#if windows
  $ setconfig "hooks.post-worktree-add=cmd /c exit 1"
  $ sl worktree add $TESTTMP/hook_linked_fail
  created linked worktree at $TESTTMP/hook_linked_fail
#else
  $ setconfig hooks.post-worktree-add=false
  $ sl worktree add $TESTTMP/hook_linked_fail
  created linked worktree at $TESTTMP/hook_linked_fail
#endif
  $ test -d $TESTTMP/hook_linked_fail

test worktree add - pre-worktree-add hook fires with correct env vars

#if windows
  $ setconfig hooks.pre-worktree-add="echo PATH:%HG_PATH% SOURCE:%HG_SOURCE%"
  $ sl worktree add $TESTTMP/pre_hook_linked
  PATH:$TESTTMP?pre_hook_linked SOURCE:$TESTTMP?hook_repo\r (esc) (glob)
  created linked worktree at $TESTTMP/pre_hook_linked
#else
  $ setconfig hooks.pre-worktree-add="echo PATH:\$HG_PATH SOURCE:\$HG_SOURCE"
  $ sl worktree add $TESTTMP/pre_hook_linked
  PATH:$TESTTMP/pre_hook_linked SOURCE:$TESTTMP/hook_repo
  created linked worktree at $TESTTMP/pre_hook_linked
#endif

test worktree add - pre-worktree-add hook failure aborts command

#if windows
  $ setconfig "hooks.pre-worktree-add=cmd /c exit 1"
  $ sl worktree add $TESTTMP/pre_hook_blocked
  abort: pre-worktree-add hook exited with status 1
  [255]
#else
  $ setconfig hooks.pre-worktree-add=false
  $ sl worktree add $TESTTMP/pre_hook_blocked
  abort: pre-worktree-add hook exited with status 1
  [255]
#endif
  $ test -d $TESTTMP/pre_hook_blocked
  [1]
