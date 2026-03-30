/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::io::BufRead;
use std::path::Path;
use std::path::PathBuf;

use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::Result;
use repo::repo::Repo;
use worktree::dissolve_group;
use worktree::with_registry_lock;

use crate::WorktreeOpts;
use crate::require_group;

pub(crate) fn run(ctx: &ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<u8> {
    let logger = ctx.logger();
    let (shared_store_path, group_id) = require_group(repo)?;

    if ctx.opts.all {
        return run_remove_all(ctx, repo, &shared_store_path, &group_id);
    }

    let target_str = match ctx.opts.args.get(1) {
        Some(value) => value,
        None => abort!("usage: sl worktree remove PATH"),
    };
    let target =
        util::path::strip_unc_prefix(util::path::canonical_path_allow_missing(target_str)?);

    with_registry_lock(&shared_store_path, |registry| {
        let grp = match registry.groups.get_mut(&group_id) {
            Some(group) => group,
            None => abort!("group '{}' not found in registry", group_id),
        };
        if !grp.worktrees.contains_key(&target) {
            if let Some(parent_wt) = grp.worktrees.keys().find(|wt| target.starts_with(wt)) {
                abort!(
                    "{} is not the root of checkout {}, not removing",
                    target.display(),
                    parent_wt.display()
                );
            }
            abort!(
                "{} is not in this worktree group, use `eden rm` instead",
                target.display()
            );
        }
        if target == grp.main {
            abort!("cannot remove a main worktree with linked worktrees");
        }

        confirm_remove(ctx, &[&target])?;

        let pre_hooks = hook::Hooks::from_config(repo.config(), ctx.io(), "pre-worktree-remove");
        pre_hooks.run_hooks(
            Some(repo),
            true,
            Some(&HashMap::from([
                ("path".to_string(), target.display().to_string()),
                (
                    "keep".to_string(),
                    if ctx.opts.keep {
                        "true".to_string()
                    } else {
                        String::new()
                    },
                ),
            ])),
        )?;

        if !ctx.opts.keep {
            edenfs_client::run_eden_remove(repo.config().as_ref(), &target)?;
        }
        grp.worktrees.remove(&target);
        let linked_count = grp.worktrees.keys().filter(|p| **p != grp.main).count();
        if linked_count == 0 {
            dissolve_group(registry, &group_id);
        }
        Ok(())
    })?;

    let action = if ctx.opts.keep { "unlinked" } else { "removed" };
    logger.info(format!("{} {}", action, target.display()));

    // NOTE: Add post-worktree-remove hook if the need arises. Note that the
    // hook's cwd (repo.path()) may not exist if the user removed the worktree
    // they were standing in (see D98226466).

    Ok(0)
}

fn run_remove_all(
    ctx: &ReqCtx<WorktreeOpts>,
    repo: &Repo,
    shared_store_path: &Path,
    group_id: &str,
) -> Result<u8> {
    let logger = ctx.logger();
    let removed_paths = with_registry_lock(shared_store_path, |registry| {
        let grp = match registry.groups.get_mut(group_id) {
            Some(group) => group,
            None => abort!("group '{}' not found in registry", group_id),
        };
        let linked_paths: Vec<PathBuf> = grp
            .worktrees
            .keys()
            .filter(|p| **p != grp.main)
            .cloned()
            .collect();

        if linked_paths.is_empty() {
            return Ok(Vec::new());
        }

        let path_refs: Vec<&Path> = linked_paths.iter().map(|p| p.as_path()).collect();
        confirm_remove(ctx, &path_refs)?;

        let pre_hooks = hook::Hooks::from_config(repo.config(), ctx.io(), "pre-worktree-remove");
        for path in &linked_paths {
            pre_hooks.run_hooks(
                Some(repo),
                true,
                Some(&HashMap::from([
                    ("path".to_string(), path.display().to_string()),
                    (
                        "keep".to_string(),
                        if ctx.opts.keep {
                            "true".to_string()
                        } else {
                            String::new()
                        },
                    ),
                ])),
            )?;
        }

        for path in &linked_paths {
            if !ctx.opts.keep {
                edenfs_client::run_eden_remove(repo.config().as_ref(), path)?;
            }
            grp.worktrees.remove(path);
        }

        dissolve_group(registry, group_id);
        Ok(linked_paths)
    })?;
    if removed_paths.is_empty() {
        logger.info("no linked worktrees to remove");
        return Ok(0);
    }
    let action = if ctx.opts.keep { "unlinked" } else { "removed" };
    for path in &removed_paths {
        logger.info(format!("{} {}", action, path.display()));
    }

    // NOTE: Add post-worktree-remove hook if the need arises. See single-remove
    // path above for cwd caveat.

    Ok(0)
}

fn confirm_remove(ctx: &ReqCtx<WorktreeOpts>, paths: &[&Path]) -> Result<()> {
    if ctx.global_opts().noninteractive {
        return Ok(());
    }

    let is_interactive = ctx.io().with_input(|input| input.is_tty());
    if !is_interactive {
        abort!("running non-interactively, use -y instead");
    }

    let action = if ctx.opts.keep { "unlink" } else { "remove" };
    if paths.len() == 1 {
        ctx.io()
            .write(format!("will {} {}\n", action, paths[0].display()))?;
    } else {
        ctx.io()
            .write(format!("will {} {} worktrees:\n", action, paths.len()))?;
        for p in paths {
            ctx.io().write(format!("  {}\n", p.display()))?;
        }
    }
    ctx.io().write("proceed? [y/N] ")?;
    ctx.io().flush()?;

    let mut input = ctx.io().input();
    let mut line = String::new();
    let mut reader = std::io::BufReader::new(&mut input);
    reader.read_line(&mut line)?;
    let answer = line.trim();
    if !(answer.eq_ignore_ascii_case("y") || answer.eq_ignore_ascii_case("yes")) {
        abort!("aborted by user");
    }
    Ok(())
}
