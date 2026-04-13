/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

pub mod cache;

use std::time::Duration;

use anyhow::Result;
use anyhow::anyhow;
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

/// Extract the username from an author string.
///
/// Tries the standard `Name <user@host>` format first, returning the email
/// prefix. When `allow_bare_unixname` is true (JK-gated), also accepts bare
/// unixnames as a fallback for non-standard commit authors (e.g. Sandcastle).
///
/// Returns `Ok(Some(username))` on success, `Ok(None)` when the format is
/// non-standard and bare unixnames are not allowed, or `Err` when bare
/// unixnames are allowed but the author string is invalid.
pub fn parse_author_username(author: &str, allow_bare_unixname: bool) -> Result<Option<&str>> {
    // Try standard format: "Name <user@host>"
    if let Some(lt) = author.find('<') {
        if let Some(gt) = author.find('>') {
            if gt > lt + 1 {
                let email = &author[lt + 1..gt];
                if let Some(at) = email.find('@') {
                    if at > 0 {
                        return Ok(Some(&email[..at]));
                    }
                }
            }
        }
    }

    // Non-standard format
    if !allow_bare_unixname {
        return Ok(None);
    }

    // Try bare email format: "user@host" (no angle brackets).
    // Extract the part before '@' and validate it as a unixname.
    if let Some(at) = author.find('@') {
        let prefix = &author[..at];
        if is_valid_bare_unixname(prefix) {
            return Ok(Some(prefix));
        }
    }

    // Try bare unixname (no '@')
    if is_valid_bare_unixname(author) {
        return Ok(Some(author));
    }

    Err(anyhow!(
        "Could not parse author '{}'. Accepted formats: \
         'Name <user@host>', 'user@host', or a bare unixname \
         (lowercase alphanumeric, dots, underscores, hyphens only)",
        author,
    ))
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
    /// Parsed username extracted from the changeset author (email prefix
    /// from "Name <user@host>" format, or bare unixname when JK-enabled).
    /// `None` when the author format is non-standard and bare unixnames
    /// are not allowed.
    pub parsed_username: Option<String>,
}

/// Inspect a changeset for config-stable eligibility.
/// Returns `Some(info)` if the changeset is eligible and touches the
/// configured directories, `None` otherwise.
pub fn inspect_changeset_eligibility(
    changeset: &BonsaiChangeset,
    eligibility_checks: &[EligibilityCheck],
    directories: &[String],
    allow_bare_unixname: bool,
) -> Option<EligibleChangesetInfo> {
    if !is_eligible_for_rate_limit(eligibility_checks, changeset) {
        return None;
    }
    if !touches_directories(changeset, directories) {
        return None;
    }
    let parsed_username = parse_author_username(changeset.author(), allow_bare_unixname)
        .ok()
        .flatten()
        .map(|u| u.to_owned());
    Some(EligibleChangesetInfo { parsed_username })
}

/// Check whether an eligible changeset matches the caller-specific user filter.
pub fn matches_user_filter(info: &EligibleChangesetInfo, user_filter: Option<&str>) -> bool {
    match user_filter {
        None => true,
        Some(username) => info.parsed_username.as_deref() == Some(username),
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

fn is_valid_bare_unixname(s: &str) -> bool {
    !s.is_empty()
        && s.bytes()
            .all(|b| matches!(b, b'a'..=b'z' | b'0'..=b'9' | b'.' | b'_' | b'-'))
}

#[cfg(test)]
mod tests {
    use mononoke_macros::mononoke;

    use super::*;

    #[mononoke::test]
    fn test_parse_standard_format() {
        assert_eq!(
            parse_author_username("Alice <alice@fb.com>", false).unwrap(),
            Some("alice")
        );
    }
    #[mononoke::test]
    fn test_parse_standard_format_bare_enabled() {
        assert_eq!(
            parse_author_username("Alice <alice@fb.com>", true).unwrap(),
            Some("alice")
        );
    }
    #[mononoke::test]
    fn test_parse_different_name_vs_email() {
        assert_eq!(
            parse_author_username("bob <robert@meta.com>", false).unwrap(),
            Some("robert")
        );
    }
    #[mononoke::test]
    fn test_parse_dotted_email_prefix() {
        assert_eq!(
            parse_author_username("Jane <jane.doe@fb.com>", false).unwrap(),
            Some("jane.doe")
        );
    }
    #[mononoke::test]
    fn test_parse_non_standard_jk_off() {
        assert_eq!(parse_author_username("twsvcscm", false).unwrap(), None);
    }
    #[mononoke::test]
    fn test_parse_bare_at_sign_jk_off() {
        assert_eq!(
            parse_author_username("twsvcscm@hostname", false).unwrap(),
            None
        );
    }
    #[mononoke::test]
    fn test_parse_bare_unixname_jk_on() {
        assert_eq!(
            parse_author_username("twsvcscm", true).unwrap(),
            Some("twsvcscm")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_dots_jk_on() {
        assert_eq!(
            parse_author_username("jane.doe", true).unwrap(),
            Some("jane.doe")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_hyphens_jk_on() {
        assert_eq!(
            parse_author_username("ci-bot", true).unwrap(),
            Some("ci-bot")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_underscores_jk_on() {
        assert_eq!(
            parse_author_username("svc_user", true).unwrap(),
            Some("svc_user")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_digits_jk_on() {
        assert_eq!(
            parse_author_username("user123", true).unwrap(),
            Some("user123")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_email_jk_on() {
        // Bare email "user@host" extracts the part before '@'
        assert_eq!(
            parse_author_username("twsvcscm@hostname", true).unwrap(),
            Some("twsvcscm")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_email_long_hostname_jk_on() {
        assert_eq!(
            parse_author_username(
                "twsvcscm@abb6-05e3-0004-0000.twshared29230.02.rcd1.tw.fbinfra.net",
                true,
            )
            .unwrap(),
            Some("twsvcscm")
        );
    }
    #[mononoke::test]
    fn test_parse_bare_email_invalid_prefix_jk_on_rejected() {
        // Bare email with invalid prefix (uppercase) should be rejected
        assert!(parse_author_username("BadUser@hostname", true).is_err());
    }
    #[mononoke::test]
    fn test_parse_uppercase_jk_on_rejected() {
        assert!(parse_author_username("UPPERCASE", true).is_err());
    }
    #[mononoke::test]
    fn test_parse_mixed_case_jk_on_rejected() {
        assert!(parse_author_username("UserName", true).is_err());
    }
    #[mononoke::test]
    fn test_parse_spaces_jk_on_rejected() {
        assert!(parse_author_username("has spaces", true).is_err());
    }
    #[mononoke::test]
    fn test_parse_slash_jk_on_rejected() {
        assert!(parse_author_username("path/user", true).is_err());
    }
    #[mononoke::test]
    fn test_parse_empty_jk_off() {
        assert_eq!(parse_author_username("", false).unwrap(), None);
    }
    #[mononoke::test]
    fn test_parse_empty_jk_on_rejected() {
        assert!(parse_author_username("", true).is_err());
    }
}
