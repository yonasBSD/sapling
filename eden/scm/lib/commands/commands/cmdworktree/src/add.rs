/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;

use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::Result;
use fs_err as fs;
use repo::repo::Repo;
use uuid::Uuid;
use worktree::Group;
use worktree::WorktreeEntry;
use worktree::check_dest_not_in_repo;
use worktree::with_registry_lock;

use crate::WorktreeOpts;

pub(crate) fn run(ctx: &ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<u8> {
    let logger = ctx.logger();
    let dest_str = match ctx.opts.args.get(1) {
        Some(value) => value,
        None => abort!("usage: sl worktree add PATH"),
    };
    let dest = util::path::strip_unc_prefix(util::path::canonical_path_allow_missing(dest_str)?);

    // Fast-fail before locking (re-checked inside lock).
    if dest.exists() {
        abort!("destination path '{}' already exists", dest.display());
    }
    check_dest_not_in_repo(&dest)?;

    let shared_store_path = repo.store_path().to_path_buf();

    let source_client_dir = edenfs_client::get_client_dir(repo.path())?;

    // Get the source repo's current commit so the new worktree starts at the same revision.
    let parents = workingcopy::fast_path_wdir_parents(repo.path(), repo.ident())?;
    let target = parents.p1().copied();

    // Replicate the source repo's scm type and active filters.
    // When edensparse is in requirements, the backing store should be filteredhg
    // (even with no filter paths configured). Otherwise the backing store is hg.
    // Read active filter paths from the source repo's .sl/sparse file.
    let clone_filters = repo
        .requirements
        .contains("edensparse")
        .then(|| -> anyhow::Result<_> {
            let paths = filters::util::read_filter_config(repo.dot_hg_path())?
                .map(|paths| paths.into_iter().map(|p| p.into_string().into()).collect())
                .unwrap_or_default();
            Ok(paths)
        })
        .transpose()?;

    // Pre-compute the canonical path for the source repo before acquiring the lock.
    let canonical_repo_path = fs::canonicalize(repo.path())
        .map(util::path::strip_unc_prefix)
        .unwrap_or_else(|_| repo.path().to_path_buf());

    let pre_hooks = hook::Hooks::from_config(repo.config(), ctx.io(), "pre-worktree-add");
    pre_hooks.run_hooks(
        Some(repo),
        true,
        Some(&HashMap::from([
            ("path".to_string(), dest.display().to_string()),
            (
                "source".to_string(),
                canonical_repo_path.display().to_string(),
            ),
        ])),
    )?;

    // Hold the registry lock across the clone and registry update so that
    // concurrent `worktree add` calls are serialized. The dest.exists()
    // check is repeated here while holding the lock to guard against races
    // in parallel `worktree add` calls, allowing us to cleanly exit rather
    // than letting clone fail.
    with_registry_lock(&shared_store_path, |registry| {
        if dest.exists() {
            abort!("destination path '{}' already exists", dest.display());
        }

        let existing_group_id = registry.find_group_for_path(&canonical_repo_path);
        let group_id = existing_group_id.unwrap_or_else(|| format!("{:x}", Uuid::new_v4()));

        // Create new EdenFS working copy.
        //
        // NOTE: If eden_clone fails after partially creating the checkout, EdenFS may have already
        // registered the mount. The registry won't be updated (we return early on error),
        // leaving an orphan checkout.
        //
        // If holding the registry lock for the duration of the clone is too
        // expensive, consider reserving the path in the registry (or a per-path
        // lock) before cloning, then finalizing the entry afterward.
        if let Err(err) = clone::eden_clone(repo, &dest, target, clone_filters) {
            ctx.logger().warn(format!(
                "worktree add may have left a partial checkout; try running `eden rm {}` to recover",
                dest.display()
            ));
            return Err(err);
        }

        // Copy the sparse/filter config so the new worktree has the same active filters.
        clone::copy_sparse_config(repo.dot_hg_path(), &dest.join(repo.ident().dot_dir()))?;

        // Copy user-specific EdenFS config (redirections, prefetch profiles) from
        // the source worktree to the new one. Repo-level redirections from
        // .eden-redirections are applied automatically by the clone.
        clone::copy_eden_user_config(repo.config().as_ref(), &source_client_dir, &dest)?;

        let grp = registry
            .groups
            .entry(group_id.clone())
            .or_insert_with(|| Group::new(canonical_repo_path.clone()));

        grp.worktrees.insert(
            dest.clone(),
            WorktreeEntry {
                added: chrono::Utc::now().to_rfc3339(),
                label: if ctx.opts.label.is_empty() {
                    None
                } else {
                    Some(ctx.opts.label.clone())
                },
            },
        );

        Ok(())
    })?;

    logger.info(format!("created linked worktree at {}", dest.display()));

    let post_hooks = hook::Hooks::from_config(repo.config(), ctx.io(), "post-worktree-add");
    post_hooks.run_hooks(
        Some(repo),
        false,
        Some(&HashMap::from([
            ("path".to_string(), dest.display().to_string()),
            (
                "source".to_string(),
                canonical_repo_path.display().to_string(),
            ),
        ])),
    )?;

    Ok(0)
}
