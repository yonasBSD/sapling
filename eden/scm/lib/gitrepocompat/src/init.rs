/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::path::MAIN_SEPARATOR_STR as SEP;
use std::path::Path;

use anyhow::Result;
use fs_err as fs;
use gitcompat::init::init_empty_dirstate;
use identity::Identity;

/// Initialize and update Sapling's dotdir inside `.repo/`.
///
/// `dot_dir` is expected to be `**/.repo/sl`
pub fn maybe_init_inside_dotrepo(root_path: &Path, ident: Identity) -> Result<()> {
    if !ident.is_dot_repo() {
        return Ok(());
    }

    let dot_repo_path = root_path.join(".repo");
    let dot_dir = dot_repo_path.join("sl");
    let store_dir = dot_dir.join("store");

    if !dot_dir.join("requires").exists() {
        fs::create_dir_all(&dot_dir)?;
        fs::write(dot_dir.join("requires"), "store\ndotrepo\n")?;
    }
    if !store_dir.join("requires").exists() {
        fs::create_dir_all(&store_dir)?;
        fs::write(
            store_dir.join("requires"),
            "narrowheads\nvisibleheads\ngit\ngit-store\ndotrepo\n",
        )?;
        fs::write(
            store_dir.join("gitdir"),
            format!("..{SEP}..{SEP}manifests{SEP}.git"),
        )?;
        // Write an empty eden dirstate so it can be loaded.
        init_empty_dirstate(&dot_dir)?;
    }

    Ok(())
}
