/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#![allow(unexpected_cfgs)]

// [cats]
// entry_name.priority=20
// entry_name.path=/var/boo/cat
// entry_name.type=forwarded  # If not present, "forwarded" is the default.
// different_entry_name.priority=5
// different_entry_name.more_custom_data=/some/other
// different_entry_name.type=auth

use std::collections::HashMap;
use std::path::PathBuf;
use std::str;

use anyhow::Result;
use configmodel::Config;
use configmodel::ConfigExt;
use configmodel::Text;
use indexmap::IndexMap;
use serde::Deserialize;
use serde::Serialize;
use thiserror::Error;
use util::path::expand_path;

#[derive(Debug, Error)]
#[error("File containing CATs not found in {missing:?}.")]
pub struct MissingCATs {
    missing: Vec<PathBuf>,
}

#[derive(Serialize, Deserialize)]
struct Cats {
    crypto_auth_tokens: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CatTokenType {
    Forwarded,
    Auth,
}

impl CatTokenType {
    pub fn from_type_str(s: &str) -> Result<Self> {
        match s {
            "forwarded" => Ok(Self::Forwarded),
            "auth" => Ok(Self::Auth),
            other => anyhow::bail!("unknown CAT token type: {}", other),
        }
    }

    pub fn header_name(&self) -> &'static str {
        match self {
            Self::Forwarded => cats_constants::X_FORWARDED_CATS_HEADER,
            Self::Auth => cats_constants::X_AUTH_CATS_HEADER,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CatGroup {
    pub name: String,
    pub priority: i32,
    pub path: Option<PathBuf>,
    pub token_type: CatTokenType,
}

impl CatGroup {
    fn new(group: &str, mut settings: HashMap<&str, Text>) -> Result<Self> {
        let name = group.into();

        let path = settings
            .remove("path")
            .filter(|s| !s.is_empty())
            .map(expand_path);

        let priority = settings
            .remove("priority")
            .map(|s| s.parse())
            .transpose()?
            .unwrap_or_default();

        let token_type = settings
            .remove("type")
            .map(|s| CatTokenType::from_type_str(&s))
            .transpose()?
            .unwrap_or(CatTokenType::Forwarded);

        Ok(Self {
            name,
            priority,
            path,
            token_type,
        })
    }
}

#[derive(Clone)]
pub struct CatsSection<'a> {
    groups: Vec<CatGroup>,
    #[allow(dead_code)]
    config: &'a dyn Config,
}

impl<'a> CatsSection<'a> {
    pub fn from_config(config: &'a dyn Config, section_name: &str) -> Self {
        // Use an IndexMap to preserve ordering; needed to correctly handle precedence.
        let mut groups = IndexMap::new();

        let keys = config.keys(section_name);
        for key in &keys {
            // Skip keys that aren't valid UTF-8 or that don't match
            // the expected cats key format of `group.setting`.
            let (group, setting) = match key.find('.') {
                Some(i) => (&key[..i], &key[i + 1..]),
                None => continue,
            };
            if let Some(value) = config.get(section_name, key) {
                groups
                    .entry(group)
                    .or_insert_with(HashMap::new)
                    .insert(setting, value);
            }
        }

        let groups = groups
            .into_iter()
            .filter_map(|(group, settings)| CatGroup::new(group, settings).ok())
            .collect();

        Self { groups, config }
    }

    /// Find existing cats with highest priority, filtered by token type.
    pub fn find_cats_by_type(
        &self,
        token_type: CatTokenType,
    ) -> Result<Option<CatGroup>, MissingCATs> {
        let mut best: Option<&CatGroup> = None;
        let mut missing = Vec::new();

        for group in self.groups.iter().filter(|g| g.token_type == token_type) {
            // If there is an existing candidate, check whether the current
            // cats entry is a more specific match.
            if let Some(best) = best {
                // If prefixes are the same, break the tie using priority.
                if group.priority < best.priority {
                    continue;
                }
            }

            // Skip this group is any of the files are missing.
            match &group.path {
                Some(path) if !path.is_file() => {
                    tracing::debug!(
                        "Ignoring [cats] group {:?} because of missing {:?}",
                        &group.name,
                        &path
                    );
                    missing.push(path.to_path_buf());
                    continue;
                }
                _ => {}
            }

            best = Some(group);
        }

        if let Some(best) = best {
            Ok(Some(best.clone()))
        } else if !missing.is_empty() {
            Err(MissingCATs { missing })
        } else {
            Ok(None)
        }
    }

    pub fn get_cats_by_type(&self, token_type: CatTokenType) -> Result<Option<String>> {
        match self.find_cats_by_type(token_type) {
            Ok(Some(cats_group)) => {
                // The "preminted" config group (Dev Docker Images) uses a
                // multi-token file format. Use the preminted library to get
                // merged tokens (verify_integrity + interngraph) instead of
                // just the crypto_auth_tokens key from the JSON blob.
                #[cfg(all(fbcode_build, target_os = "linux"))]
                if cats_group.name == "preminted" {
                    tracing::debug!("config group 'preminted'; using preminted CATs library");
                    return self.try_preminted_cats();
                }

                if let Some(path) = cats_group.path {
                    let f = std::fs::File::open(&path)?;
                    let reader = std::io::BufReader::new(f);
                    let cats: Cats = serde_json::from_reader(reader)?;
                    return Ok(Some(cats.crypto_auth_tokens));
                }
            }
            Ok(None) => {}
            Err(e) => {
                // If all configured groups are "preminted" (Dev Docker Images),
                // a missing file is expected during container lease provisioning.
                // For other groups (e.g. sandcastle), propagate the error.
                if self.groups.iter().all(|g| g.name == "preminted") {
                    tracing::debug!("pre-minted CATs file not yet available: {e}");
                } else {
                    return Err(e.into());
                }
            }
        }

        // Config-based CATs not available; try pre-minted as fallback.
        self.try_preminted_cats()
    }

    #[cfg(all(fbcode_build, target_os = "linux"))]
    fn preminted_wanted_keys(&self) -> Vec<String> {
        let default = || {
            vec![
                platform_cats_reader::CAT_KEY_VERIFY_INTEGRITY.to_string(),
                platform_cats_reader::CAT_KEY_INTERNGRAPH.to_string(),
                platform_cats_reader::CAT_KEY_SCM_SERVICE_IDENTITY.to_string(),
            ]
        };
        self.config
            .get_or("cats", "preminted-wanted-keys", default)
            .unwrap_or_else(|_| default())
    }

    #[cfg(all(fbcode_build, target_os = "linux"))]
    fn try_preminted_cats(&self) -> Result<Option<String>> {
        let wanted_keys = self.preminted_wanted_keys();

        // Check if any pre-minted CATs exist on this machine.
        let all_cats = platform_cats_reader::read_all_preminted_cats();
        if all_cats.is_empty() {
            return Ok(None);
        }

        // Pre-minted CATs exist — check if our required keys are present.
        let missing: Vec<&str> = wanted_keys
            .iter()
            .filter(|k| !all_cats.contains_key(k.as_str()))
            .map(|k| k.as_str())
            .collect();

        if !missing.is_empty() {
            tracing::debug!(
                ?missing,
                "pre-minted CATs missing required keys; not using pre-minted CATs"
            );
            return Ok(None);
        }

        // Read the already-merged "crypto_auth_tokens" key directly,
        // avoiding the heavyweight cryptocat dependency that
        // read_merged_preminted_cats_for() would pull in.
        match all_cats.get(platform_cats_reader::CAT_KEY_MERGED) {
            Some(cats) => {
                tracing::debug!("using pre-minted CATs for authentication");
                Ok(Some(cats.clone()))
            }
            None => Ok(None),
        }
    }

    #[cfg(not(all(fbcode_build, target_os = "linux")))]
    fn try_preminted_cats(&self) -> Result<Option<String>> {
        Ok(None)
    }
}
