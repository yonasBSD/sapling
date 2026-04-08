/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

pub mod cache;

use std::time::Duration;

use anyhow::Result;
use metaconfig_types::CommitRateLimitConfig;
use mononoke_types::BonsaiChangeset;
use serde::Deserialize;

use crate::cache::ChangesetEligibilityCache;

// --- Facet ---

/// Repository facet that holds the commit rate limit rules.
#[facet::facet]
pub struct CommitRateLimit {
    rules: Vec<CommitRateLimitRule>,
}

impl CommitRateLimit {
    pub fn new(rules: Vec<CommitRateLimitRule>) -> Self {
        Self { rules }
    }

    pub fn empty() -> Self {
        Self { rules: vec![] }
    }

    pub fn rules(&self) -> &[CommitRateLimitRule] {
        &self.rules
    }
}

// --- Config types ---

const DEFAULT_CACHE_MAX_ENTRIES: u64 = 50000;
const DEFAULT_CACHE_TTL_SECS: u64 = 300;

/// Maximum allowed rate limit window (6 hours). Larger windows risk
/// performance issues due to unbounded history traversal and cache misses.
pub const MAX_RATE_LIMIT_WINDOW_SECS: u64 = 6 * 60 * 60;

fn default_cache_max_entries() -> u64 {
    DEFAULT_CACHE_MAX_ENTRIES
}

fn default_cache_ttl_secs() -> u64 {
    DEFAULT_CACHE_TTL_SECS
}

/// Configuration for the in-memory eligibility cache.
///
/// When present in the hook config, a bounded moka cache is constructed.
/// When absent, no caching is performed.
#[derive(Deserialize, Clone, Debug)]
pub struct CommitRateLimitCacheConfig {
    #[serde(default = "default_cache_max_entries")]
    pub max_entries: u64,
    #[serde(default = "default_cache_ttl_secs")]
    pub ttl_secs: u64,
}

impl CommitRateLimitCacheConfig {
    /// Build a bounded cache from this config.
    ///
    /// Returns `None` when `max_entries == 0` (cache disabled).
    /// Clamps `ttl_secs` to a minimum of 1 so that `max_entries` is the
    /// only off-switch.
    pub fn build_cache(&self) -> Option<ChangesetEligibilityCache> {
        if self.max_entries == 0 {
            return None;
        }
        let ttl = Duration::from_secs(self.ttl_secs.max(1));
        Some(ChangesetEligibilityCache::new(self.max_entries, ttl))
    }
}

#[derive(Deserialize, Clone, Debug)]
pub struct CommitRateLimitRule {
    /// Repository name, set by the hook adapter for ODS tagging.
    #[serde(skip)]
    repo_name: String,
    /// Rate limit name (typically the hook name), for ODS tagging.
    #[serde(skip)]
    name: String,
    /// Checks that determine if a commit is eligible for rate limiting (OR semantics).
    eligibility_checks: Vec<EligibilityCheck>,
    /// Rate limit windows -- all must pass for the commit to be allowed.
    limits: Vec<RateLimit>,
    /// Optional directory prefixes to scope the rate limit to.
    /// If empty, all directories are in scope.
    #[serde(default)]
    directories: Vec<String>,
    /// Whether to enforce limits per-author (true) or globally (false).
    #[serde(default)]
    per_user: bool,
    /// Optional in-memory cache for config-stable inspection results.
    /// When present, a bounded moka cache is used to skip redundant
    /// blobstore loads.
    #[serde(default)]
    cache_config: Option<CommitRateLimitCacheConfig>,
    /// Pre-built cache instance, derived from `cache_config`.
    #[serde(skip)]
    cache: Option<ChangesetEligibilityCache>,
}

impl CommitRateLimitRule {
    /// Construct a new rule directly (used by the repo-attribute facet crate,
    /// which builds rules from the metaconfig types instead of JSON).
    pub fn new(
        name: String,
        repo_name: String,
        eligibility_checks: Vec<EligibilityCheck>,
        limits: Vec<RateLimit>,
        directories: Vec<String>,
        per_user: bool,
        cache: Option<ChangesetEligibilityCache>,
    ) -> Self {
        Self {
            name,
            repo_name,
            eligibility_checks,
            limits,
            directories,
            per_user,
            cache_config: None,
            cache,
        }
    }

    /// Set repo and rate-limit names after deserialization. These are used
    /// for ODS tagging and are not part of the JSON config.
    pub fn with_names(mut self, repo_name: String, name: String) -> Self {
        self.repo_name = repo_name;
        self.name = name;
        self
    }

    pub fn validate(&self) -> Result<()> {
        self.limits.iter().try_for_each(|limit| limit.validate())
    }

    pub fn repo_name(&self) -> &str {
        &self.repo_name
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn per_user(&self) -> bool {
        self.per_user
    }

    pub fn directories(&self) -> &[String] {
        &self.directories
    }

    pub fn eligibility_checks(&self) -> &[EligibilityCheck] {
        &self.eligibility_checks
    }

    pub fn cache_config(&self) -> Option<&CommitRateLimitCacheConfig> {
        self.cache_config.as_ref()
    }

    pub fn limits(&self) -> &[RateLimit] {
        &self.limits
    }

    pub fn cache(&self) -> Option<&ChangesetEligibilityCache> {
        self.cache.as_ref()
    }

    /// Build the cache from `cache_config` and store it in `self.cache`.
    /// Used by the legacy hook path after deserializing from JSON config.
    pub fn build_and_set_cache(&mut self) {
        self.cache = self.cache_config.as_ref().and_then(|cc| cc.build_cache());
    }
}

#[derive(Deserialize, Clone, Debug)]
#[serde(tag = "type")]
pub enum EligibilityCheck {
    /// Matches commits whose message contains the given tag string (case-sensitive).
    #[serde(rename = "commit_message_tag")]
    CommitMessageTag { tag: String },
    /// Matches commits with the given key in hg_extra.
    #[serde(rename = "hg_extra")]
    HgExtra { key: String },
    /// Always passes -- use when rate limiting all commits (e.g. scoped by
    /// directory and/or per-user) without any eligibility filter.
    #[serde(rename = "always_pass")]
    AlwaysPass,
}

impl From<metaconfig_types::CommitRateLimitEligibilityCheck> for EligibilityCheck {
    fn from(check: metaconfig_types::CommitRateLimitEligibilityCheck) -> Self {
        match check {
            metaconfig_types::CommitRateLimitEligibilityCheck::CommitMessageTag(tag) => {
                EligibilityCheck::CommitMessageTag { tag }
            }
            metaconfig_types::CommitRateLimitEligibilityCheck::HgExtra(key) => {
                EligibilityCheck::HgExtra { key }
            }
            metaconfig_types::CommitRateLimitEligibilityCheck::AlwaysPass => {
                EligibilityCheck::AlwaysPass
            }
        }
    }
}

impl EligibilityCheck {
    pub fn is_eligible(&self, changeset: &BonsaiChangeset) -> bool {
        match self {
            EligibilityCheck::CommitMessageTag { tag } => {
                changeset.message().contains(tag.as_str())
            }
            EligibilityCheck::HgExtra { key } => changeset.hg_extra().any(|(k, _)| k == key),
            EligibilityCheck::AlwaysPass => true,
        }
    }
}

#[derive(Deserialize, Clone, Debug)]
pub struct RateLimit {
    window_secs: u64,
    max_commits: u64,
}

impl TryFrom<metaconfig_types::CommitRateLimitWindow> for RateLimit {
    type Error = anyhow::Error;

    fn try_from(window: metaconfig_types::CommitRateLimitWindow) -> Result<Self> {
        RateLimit::new(window.window_secs, window.max_commits)
    }
}

impl RateLimit {
    pub fn new(window_secs: u64, max_commits: u64) -> Result<Self> {
        let rate_limit = Self {
            window_secs,
            max_commits,
        };
        rate_limit.validate()?;
        Ok(rate_limit)
    }

    pub fn validate(&self) -> Result<()> {
        anyhow::ensure!(
            self.window_secs > 0,
            "Rate limit window must be greater than 0 seconds",
        );
        anyhow::ensure!(
            self.window_secs <= MAX_RATE_LIMIT_WINDOW_SECS,
            "Rate limit window ({} seconds) exceeds maximum ({} seconds / 6 hours). \
             Larger windows may cause performance issues due to history traversal.",
            self.window_secs,
            MAX_RATE_LIMIT_WINDOW_SECS,
        );
        anyhow::ensure!(
            self.max_commits > 0,
            "Rate limit max_commits must be greater than 0",
        );
        Ok(())
    }

    pub fn window_secs(&self) -> u64 {
        self.window_secs
    }

    pub fn max_commits(&self) -> u64 {
        self.max_commits
    }
}

// --- Helper functions ---

/// Extract the username from an author string of the form "Name <user@host>".
///
/// Returns `Some(username)` where username is the part before `@` in the email,
/// or `None` if the author string does not match the expected format.
pub fn parse_author_username(author: &str) -> Option<&str> {
    let lt = author.find('<')?;
    let gt = author.find('>')?;
    if gt <= lt + 1 {
        return None;
    }
    let email = &author[lt + 1..gt];
    let at = email.find('@')?;
    if at == 0 {
        return None;
    }
    Some(&email[..at])
}

pub fn is_eligible_for_rate_limit(
    checks: &[EligibilityCheck],
    changeset: &BonsaiChangeset,
) -> bool {
    checks.iter().any(|check| check.is_eligible(changeset))
}

pub fn touches_directories(changeset: &BonsaiChangeset, directories: &[String]) -> bool {
    if directories.is_empty() {
        return true;
    }
    changeset.file_changes().any(|(path, _)| {
        let path_str = path.to_string();
        directories
            .iter()
            .any(|dir| path_str.starts_with(dir.as_str()))
    })
}

/// Config-stable inspection result for a single changeset.
/// Safe to cache because it depends only on hook config, not on the caller.
#[derive(Clone, Debug)]
pub struct EligibleChangesetInfo {
    pub parsed_username: Option<String>,
}

/// Inspect a changeset for config-stable eligibility.
/// Returns `Some(info)` if the changeset is eligible and touches the
/// configured directories, `None` otherwise.
pub fn inspect_changeset_eligibility(
    changeset: &BonsaiChangeset,
    eligibility_checks: &[EligibilityCheck],
    directories: &[String],
) -> Option<EligibleChangesetInfo> {
    if !is_eligible_for_rate_limit(eligibility_checks, changeset) {
        return None;
    }
    if !touches_directories(changeset, directories) {
        return None;
    }
    let parsed_username = parse_author_username(changeset.author()).map(|u| u.to_owned());
    Some(EligibleChangesetInfo { parsed_username })
}

/// Check whether an eligible changeset matches the caller-specific user filter.
pub fn matches_user_filter(info: &EligibleChangesetInfo, user_filter: Option<&str>) -> bool {
    match user_filter {
        None => true,
        Some(username) => info
            .parsed_username
            .as_deref()
            .map(|u| u == username)
            .unwrap_or(false),
    }
}

// --- Construction ---

/// Build a `CommitRateLimit` facet from the metaconfig types.
///
/// Each rule gets its own independent `ChangesetEligibilityCache` instance
/// (built from the shared `cache_config`). Caches must NOT be shared across
/// rules because the cached eligibility result depends on each rule's
/// `eligibility_checks` and `directories`.
pub fn build_commit_rate_limit(
    config: &CommitRateLimitConfig,
    repo_name: &str,
) -> Result<CommitRateLimit> {
    let rules = config
        .rules
        .iter()
        .map(|raw_rule| {
            let cache = config.cache_config.as_ref().and_then(|cc| {
                if cc.max_entries == 0 {
                    return None;
                }
                let ttl = Duration::from_secs(cc.ttl_secs.max(1));
                Some(ChangesetEligibilityCache::new(cc.max_entries, ttl))
            });

            let eligibility_checks = raw_rule
                .eligibility_checks
                .iter()
                .cloned()
                .map(Into::into)
                .collect();
            let limits = raw_rule
                .limits
                .iter()
                .cloned()
                .map(TryInto::try_into)
                .collect::<Result<Vec<_>>>()?;

            let rule = CommitRateLimitRule::new(
                raw_rule.name.clone(),
                repo_name.to_string(),
                eligibility_checks,
                limits,
                raw_rule.directories.clone(),
                raw_rule.per_user,
                cache,
            );
            rule.validate()?;
            Ok(rule)
        })
        .collect::<Result<Vec<_>>>()?;

    Ok(CommitRateLimit::new(rules))
}
