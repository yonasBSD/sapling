/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::io::BufRead;
use std::path::Path;
use std::path::PathBuf;

use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::Result;
use fs_err as fs;
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

    check_not_inside(&target)?;

    with_registry_lock(&shared_store_path, |registry| {
        let grp = match registry.groups.get_mut(&group_id) {
            Some(group) => group,
            None => abort!("group '{}' not found in registry", group_id),
        };
        if !grp.worktrees.contains_key(&target) {
            abort!(
                "'{}' is not in this worktree group, use `eden rm` instead",
                target.display()
            );
        }
        if target == grp.main {
            abort!("cannot remove a main worktree with linked worktrees");
        }

        confirm_remove(ctx, &[&target])?;

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

        for path in &linked_paths {
            check_not_inside(path)?;
        }

        let path_refs: Vec<&Path> = linked_paths.iter().map(|p| p.as_path()).collect();
        confirm_remove(ctx, &path_refs)?;

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
    Ok(0)
}

fn check_not_inside(target: &Path) -> Result<()> {
    if let Ok(cwd) = std::env::current_dir() {
        let cwd = fs::canonicalize(&cwd)
            .map(util::path::strip_unc_prefix)
            .unwrap_or(cwd);
        if cwd.starts_with(target) {
            abort!(
                "cannot remove '{}': your current working directory is inside it",
                target.display()
            );
        }
    }
    Ok(())
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_check_not_inside_outside() {
        let target = PathBuf::from("/tmp/some_nonexistent_path_for_test");
        assert!(check_not_inside(&target).is_ok());
    }

    #[test]
    fn test_starts_with_component_boundary() {
        let target = PathBuf::from("/foo/bar");
        let similar_path = PathBuf::from("/foo/bar2");
        let actual_child = PathBuf::from("/foo/bar/child");

        assert!(!similar_path.starts_with(&target));
        assert!(actual_child.starts_with(&target));
    }

    #[cfg(windows)]
    #[test]
    fn test_canonicalized_cwd_starts_with_canonical_target() {
        let root = std::env::temp_dir().join(format!("cmdworktree-{}", uuid::Uuid::new_v4()));
        let child = root.join("child");
        std::fs::create_dir_all(&root).unwrap();
        std::fs::create_dir_all(&child).unwrap();

        let canonical_target = util::path::canonical_path_allow_missing(&root).unwrap();
        let canonical_child = fs::canonicalize(&child).unwrap();

        assert!(canonical_child.starts_with(&canonical_target));

        std::fs::remove_dir_all(&root).unwrap();
    }
}
