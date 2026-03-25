/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::path::PathBuf;

use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::Result;
use fs_err as fs;
use repo::repo::Repo;
use worktree::with_registry_lock;

use crate::WorktreeOpts;
use crate::require_group;

pub(crate) fn run(ctx: &ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<u8> {
    let logger = ctx.logger();
    let (shared_store_path, group_id) = require_group(repo)?;
    let (target, new_label) = parse_label_args(ctx, repo)?;

    with_registry_lock(&shared_store_path, |registry| {
        let grp = match registry.groups.get_mut(&group_id) {
            Some(group) => group,
            None => abort!("group '{}' not found in registry", group_id),
        };
        let entry = match grp.worktrees.get_mut(&target) {
            Some(entry) => entry,
            None => abort!("'{}' is not in this worktree group", target.display()),
        };
        if ctx.opts.remove {
            entry.label = None;
        } else {
            entry.label = Some(new_label);
        }
        Ok(())
    })?;

    if ctx.opts.remove {
        logger.info(format!("label removed for {}", target.display()));
    } else {
        logger.info(format!("label set for {}", target.display()));
    }
    Ok(0)
}

fn parse_label_args(ctx: &ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<(PathBuf, String)> {
    let args = &ctx.opts.args;
    let flag_label = if ctx.opts.label.is_empty() {
        None
    } else {
        Some(ctx.opts.label.clone())
    };
    let current_worktree =
        || -> Result<PathBuf> { Ok(util::path::strip_unc_prefix(fs::canonicalize(repo.path())?)) };

    if ctx.opts.remove {
        if flag_label.is_some() {
            abort!("--label cannot be used with --remove");
        }
        return match args.len() {
            1 => Ok((current_worktree()?, String::new())),
            2 => {
                let target = util::path::strip_unc_prefix(fs::canonicalize(&args[1])?);
                Ok((target, String::new()))
            }
            _ => abort!("usage: sl worktree label [PATH] --remove"),
        };
    }

    match args.len() {
        1 => match flag_label {
            Some(label) => Ok((current_worktree()?, label)),
            None => abort!("usage: sl worktree label [PATH] TEXT"),
        },
        2 => {
            if let Some(label) = flag_label {
                let target = util::path::strip_unc_prefix(fs::canonicalize(&args[1])?);
                Ok((target, label))
            } else {
                Ok((current_worktree()?, args[1].clone()))
            }
        }
        3 => {
            if flag_label.is_some() {
                abort!("cannot specify both positional TEXT and --label");
            }
            let target = util::path::strip_unc_prefix(fs::canonicalize(&args[1])?);
            let label_text = args[2].clone();
            Ok((target, label_text))
        }
        _ => abort!("usage: sl worktree label [PATH] TEXT"),
    }
}
