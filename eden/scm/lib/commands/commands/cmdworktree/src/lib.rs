/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

mod add;
mod label;
mod list;
mod remove;

use std::path::PathBuf;

use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::ConfigExt;
use cmdutil::FormatterOpts;
use cmdutil::Result;
use cmdutil::define_flags;
use fs_err as fs;
use repo::repo::Repo;

define_flags! {
    pub struct WorktreeOpts {
        /// a short label for the worktree (for 'add' and 'label')
        #[argtype("TEXT")]
        label: String,

        /// only unlink from group, keep the checkout on disk (for 'remove')
        keep: bool,

        /// remove all linked worktrees (for 'remove')
        all: bool,

        /// remove the label instead of setting it (for 'label')
        remove: bool,

        formatter_opts: FormatterOpts,

        #[args]
        args: Vec<String>,
    }
}

pub fn run(ctx: ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<u8> {
    if !repo.config().get_or("worktree", "enabled", || false)? {
        abort!("worktree command requires --config worktree.enabled=true");
    }

    let subcmd = ctx.opts.args.first().map(|s| s.as_str()).unwrap_or("");
    match subcmd {
        "list" | "ls" => list::run(&ctx, repo),
        "add" => add::run(&ctx, repo),
        "remove" | "rm" => remove::run(&ctx, repo),
        "label" => label::run(&ctx, repo),
        "" => abort!("you need to specify a subcommand (run with --help to see a list)"),
        other => abort!("unknown worktree subcommand '{}'", other),
    }
}

pub(crate) fn require_group(repo: &Repo) -> Result<(PathBuf, String)> {
    let shared_store_path = repo.store_path();
    let registry = worktree::load_registry(shared_store_path)?;
    let current = util::path::strip_unc_prefix(fs::canonicalize(repo.path())?);
    match registry.find_group_for_path(&current) {
        Some(id) => Ok((shared_store_path.to_path_buf(), id)),
        None => abort!("this worktree is not part of a group"),
    }
}

pub fn aliases() -> &'static str {
    "worktree"
}

pub fn doc() -> &'static str {
    r#"manage multiple linked worktrees sharing the same repository

    worktree groups allow multiple EdenFS-backed working copies to share
    the same backing store. One worktree is designated as the main worktree,
    and additional linked worktrees can be created, listed, labeled, and
    removed.

    Subcommands::

      list [-Tjson]                           List all worktrees in the group
      add PATH [--label TEXT]                 Create a new linked worktree
      remove PATH [--all] [--keep] [-y]       Remove linked worktree(s)
      label [PATH] TEXT [--remove]            Set or remove a worktree label

    Currently only EdenFS-backed repositories are supported."#
}

pub fn synopsis() -> Option<&'static str> {
    Some("SUBCOMMAND [OPTIONS] [ARGS]")
}
