/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;

use anyhow::Context as _;
use anyhow::bail;
use clidispatch::ReqCtx;
use clidispatch::abort;
use cmdutil::ConfigExt;
use cmdutil::Result;
use encoding::shell_output_bytes_to_path;
use fs_err as fs;
use repo::repo::Repo;
use spawn_ext::CommandExt;
use uuid::Uuid;
use worktree::Group;
use worktree::WorktreeEntry;
use worktree::check_dest_not_in_repo;
use worktree::with_registry_lock;

use crate::WorktreeOpts;

pub(crate) fn run(ctx: &ReqCtx<WorktreeOpts>, repo: &Repo) -> Result<u8> {
    let logger = ctx.logger();

    let require_generated: bool = repo
        .config()
        .get_or_default("worktree", "require-generated-path")?;

    // Pre-compute the canonical path for the source repo early since the path generator needs it.
    let canonical_repo_path = fs::canonicalize(repo.path())
        .map(util::path::strip_unc_prefix)
        .unwrap_or_else(|_| repo.path().to_path_buf());

    let dest = match ctx.opts.args.get(1) {
        Some(value) => {
            if require_generated {
                abort!(
                    "custom worktree paths are not allowed (worktree.require-generated-path is set); \
                     run without a path argument to use the configured path generator"
                );
            }
            util::path::strip_unc_prefix(util::path::canonical_path_allow_missing(value)?)
        }
        None => run_path_generator(
            repo,
            &ctx.opts.label,
            &canonical_repo_path,
            require_generated,
        )?,
    };

    // Fast-fail before locking (re-checked inside lock).
    if dest.exists() {
        abort!("destination path '{}' already exists", dest.display());
    }

    if ctx.opts.snapshot {
        abort!("--snapshot is not yet implemented");
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

/// Runs the `worktree.path-generator` command and returns the generated path.
fn run_path_generator(
    repo: &Repo,
    label: &str,
    canonical_source: &Path,
    require_generated: bool,
) -> Result<PathBuf> {
    let generator_cmd = repo
        .config()
        .get("worktree", "path-generator")
        .with_context(|| {
            if require_generated {
                "worktree.path-generator is required when \
                 worktree.require-generated-path=true"
            } else {
                "worktree.path-generator is not configured; pass a PATH argument"
            }
        })?;

    let current_exe = std::env::current_exe().ok();
    let exe_str = current_exe
        .as_ref()
        .and_then(|p| p.to_str())
        .unwrap_or_else(|| identity::cli_name());

    let mut cmd = Command::new_shell(generator_cmd.as_ref());
    cmd.current_dir(repo.path());
    cmd.env("HG_SOURCE", canonical_source.as_os_str());
    cmd.env("SL_SOURCE", canonical_source.as_os_str());
    cmd.env("HG_LABEL", label);
    cmd.env("SL_LABEL", label);
    cmd.env("HG", exe_str);
    cmd.env("SL", exe_str);

    let output = cmd
        .output()
        .context("failed to run worktree.path-generator")?;

    if !output.status.success() {
        let mut msg = format!("worktree.path-generator exited with {}", output.status);
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stderr = stderr.trim();
        if !stderr.is_empty() {
            msg.push_str(": ");
            msg.push_str(stderr);
        }
        bail!(msg);
    }

    let path_bytes = parse_generated_path_bytes(&output.stdout)?;
    let display_path = display_path_bytes(path_bytes);
    if path_bytes.contains(&b'\0') {
        bail!(
            "worktree.path-generator returned invalid path '{}': contains NUL byte",
            display_path
        );
    }
    let path = shell_output_bytes_to_path(path_bytes)
        .context("worktree.path-generator output could not be decoded as a path")?
        .into_owned();
    if !path.is_absolute() {
        bail!(
            "worktree.path-generator must return an absolute path, got '{}'",
            display_path
        );
    }

    let path = util::path::strip_unc_prefix(
        util::path::canonical_path_allow_missing(&path).with_context(|| {
            format!(
                "worktree.path-generator returned invalid path '{}'",
                display_path
            )
        })?,
    );
    Ok(path)
}

fn parse_generated_path_bytes(stdout: &[u8]) -> Result<&[u8]> {
    let stdout = stdout
        .strip_suffix(b"\r\n")
        .or_else(|| stdout.strip_suffix(b"\n"))
        .unwrap_or(stdout);

    if stdout.is_empty() {
        bail!("worktree.path-generator returned empty output");
    }

    if stdout.contains(&b'\r') || stdout.contains(&b'\n') {
        bail!("worktree.path-generator must write exactly one path to stdout");
    }

    Ok(stdout)
}

fn display_path_bytes(bytes: &[u8]) -> String {
    if let Ok(text) = std::str::from_utf8(bytes) {
        return text.escape_debug().to_string();
    }

    let mut escaped = String::new();
    for &byte in bytes {
        for ch in std::ascii::escape_default(byte) {
            let _ = escaped.write_char(ch.into());
        }
    }
    escaped
}
