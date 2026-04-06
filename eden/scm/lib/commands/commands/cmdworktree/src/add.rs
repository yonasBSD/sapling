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
use worktree::Group;
use worktree::WorktreeEntry;
use worktree::check_dest_not_in_repo;
use worktree::group_id_for_main_path;
use worktree::load_registry;
use worktree::with_registry_lock;
use worktree::with_worktree_path_op_lock;

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
    let registry = load_registry(&shared_store_path)?;
    if registry.find_group_for_path(&dest).is_some() {
        abort!(
            "destination path '{}' is already registered as a worktree",
            dest.display()
        );
    }
    let group_main_path = resolve_group_for_main_path(&registry, &canonical_repo_path);

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

    // Lock the source checkout path only while snapshotting the source state that
    // needs to be copied into the new worktree.
    let (target, source_sparse_config, source_user_config) =
        with_worktree_path_op_lock(&shared_store_path, &canonical_repo_path, || {
            let source_client_dir = edenfs_client::get_client_dir(repo.path())?;
            let parents = workingcopy::fast_path_wdir_parents(repo.path(), repo.ident())?;
            let target = parents.p1().copied();
            let source_sparse_config = clone::snapshot_sparse_config(repo.dot_hg_path())?;
            let source_user_config = clone::snapshot_eden_user_config(&source_client_dir)?;
            Ok((target, source_sparse_config, source_user_config))
        })?;

    // Lock the destination path while creating and initializing that checkout.
    with_worktree_path_op_lock(&shared_store_path, &dest, || {
        if dest.exists() {
            abort!("destination path '{}' already exists", dest.display());
        }
        check_dest_not_in_repo(&dest)?;

        clone::eden_clone(repo, &dest, target, clone_filters).inspect_err(|_| {
            ctx.logger().warn(format!(
                "worktree add may have left a partial checkout; try running `eden rm {}` to recover",
                dest.display()
            ));
        })?;

        source_sparse_config.as_deref().map_or(Ok(()), |config| {
            clone::write_sparse_config(config, &dest.join(repo.ident().dot_dir()))
        })?;

        source_user_config.as_deref().map_or(Ok(()), |config| {
            clone::apply_eden_user_config_snapshot(repo.config().as_ref(), config, &dest)
        })?;

        Ok(())
    })?;

    with_registry_lock(&shared_store_path, |registry| {
        if registry.find_group_for_path(&dest).is_some() {
            abort!(
                "destination path '{}' is already registered as a worktree",
                dest.display()
            );
        }

        let group_id = resolve_group_id_for_main_path(registry, &group_main_path);
        let grp = registry
            .groups
            .entry(group_id.clone())
            .or_insert_with(|| Group::new(group_main_path.clone()));

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

fn resolve_group_for_main_path(
    registry: &worktree::Registry,
    canonical_repo_path: &Path,
) -> PathBuf {
    registry
        .find_group_for_path(canonical_repo_path)
        .and_then(|group_id| {
            registry
                .groups
                .get(&group_id)
                .map(|group| group.main.clone())
        })
        .unwrap_or_else(|| canonical_repo_path.to_path_buf())
}

fn resolve_group_id_for_main_path(registry: &worktree::Registry, group_main_path: &Path) -> String {
    registry
        .find_group_for_path(group_main_path)
        .unwrap_or_else(|| group_id_for_main_path(group_main_path))
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_resolve_group_id_for_main_path_reuses_legacy_group_id() {
        let mut registry = worktree::Registry::new();
        let main = PathBuf::from("/tmp/main");
        let linked = PathBuf::from("/tmp/linked");
        let legacy_group_id = "legacy-random-group-id".to_string();

        let mut group = Group::new(main.clone());
        group.worktrees.insert(
            linked.clone(),
            WorktreeEntry {
                added: "2025-01-01T00:00:00Z".to_string(),
                label: None,
            },
        );
        registry.groups.insert(legacy_group_id.clone(), group);

        let group_main = resolve_group_for_main_path(&registry, &linked);

        assert_eq!(group_main, main);
        assert_eq!(
            resolve_group_id_for_main_path(&registry, &group_main),
            legacy_group_id
        );
    }
}
