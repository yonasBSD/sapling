/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

pub mod cache;

#[cfg(test)]
mod tests;

use std::sync::Arc;
use std::time::Duration;

use anyhow::Result;
use blobstore::Loadable;
use bookmarks::BookmarkKey;
use bookmarks::BookmarksRef;
use bookmarks::Freshness;
use commit_graph::CommitGraphRef;
use context::CoreContext;
use futures::TryStreamExt;
use history_traversal::AncestorFilterOptions;
use history_traversal::matching_ancestors_stream;
use mononoke_types::BonsaiChangeset;
use repo_blobstore::RepoBlobstoreRef;
use repo_derived_data::RepoDerivedDataRef;
use serde::Deserialize;
use stats::prelude::*;

define_stats! {
    prefix = "mononoke.commit_rate_limit";
    eligibility_cache_public_hit: dynamic_timeseries("{}.{}.public_hit", (repo_name: String, rate_limit_name: String); Rate, Sum),
    eligibility_cache_public_miss: dynamic_timeseries("{}.{}.public_miss", (repo_name: String, rate_limit_name: String); Rate, Sum),
    eligibility_cache_draft_hit: dynamic_timeseries("{}.{}.draft_hit", (repo_name: String, rate_limit_name: String); Rate, Sum),
    eligibility_cache_draft_miss: dynamic_timeseries("{}.{}.draft_miss", (repo_name: String, rate_limit_name: String); Rate, Sum),
}

// --- Repo trait ---

/// Trait alias for repository types that provide the facets needed by
/// commit rate limiting: bookmarks, blobstore, commit graph, and derived data.
pub trait Repo:
    BookmarksRef
    + RepoBlobstoreRef
    + CommitGraphRef
    + RepoDerivedDataRef
    + Clone
    + Send
    + Sync
    + 'static
{
}

impl<T> Repo for T where
    T: BookmarksRef
        + RepoBlobstoreRef
        + CommitGraphRef
        + RepoDerivedDataRef
        + Clone
        + Send
        + Sync
        + 'static
{
}

// --- Config types ---

const DEFAULT_CACHE_MAX_ENTRIES: u64 = 50000;
const DEFAULT_CACHE_TTL_SECS: u64 = 300;

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
    max_entries: u64,
    #[serde(default = "default_cache_ttl_secs")]
    ttl_secs: u64,
}

impl CommitRateLimitCacheConfig {
    /// Build a bounded cache from this config.
    ///
    /// Returns `None` when `max_entries == 0` (cache disabled).
    /// Clamps `ttl_secs` to a minimum of 1 so that `max_entries` is the
    /// only off-switch.
    pub fn build_cache(&self) -> Option<cache::ChangesetEligibilityCache> {
        if self.max_entries == 0 {
            return None;
        }
        let ttl = Duration::from_secs(self.ttl_secs.max(1));
        Some(cache::ChangesetEligibilityCache::new(self.max_entries, ttl))
    }
}

#[derive(Deserialize, Clone, Debug)]
pub struct CommitRateLimitConfig {
    /// Repository name, set by the hook adapter for ODS tagging.
    #[serde(skip)]
    repo_name: String,
    /// Rate limit name (typically the hook name), for ODS tagging.
    #[serde(skip)]
    rate_limit_name: String,
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
}

impl CommitRateLimitConfig {
    /// Set repo and rate-limit names after deserialization. These are used
    /// for ODS tagging and are not part of the JSON config.
    pub fn with_names(mut self, repo_name: String, rate_limit_name: String) -> Self {
        self.repo_name = repo_name;
        self.rate_limit_name = rate_limit_name;
        self
    }

    pub fn validate(&self) -> Result<()> {
        self.limits.iter().try_for_each(|limit| limit.validate())
    }

    pub fn repo_name(&self) -> &str {
        &self.repo_name
    }

    pub fn rate_limit_name(&self) -> &str {
        &self.rate_limit_name
    }

    pub fn per_user(&self) -> bool {
        self.per_user
    }

    pub fn directories(&self) -> &[String] {
        &self.directories
    }

    pub fn cache_config(&self) -> Option<&CommitRateLimitCacheConfig> {
        self.cache_config.as_ref()
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

/// Maximum allowed rate limit window (6 hours). Larger windows risk
/// performance issues due to unbounded history traversal and cache misses.
const MAX_RATE_LIMIT_WINDOW_SECS: u64 = 6 * 60 * 60;

#[derive(Deserialize, Clone, Debug)]
pub struct RateLimit {
    window_secs: u64,
    max_commits: u64,
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

// --- Outcome type ---

#[derive(Debug, PartialEq, Eq)]
pub enum RateLimitOutcome {
    Allowed,
    Exceeded {
        total: u64,
        window_secs: u64,
        max_commits: u64,
    },
}

// --- Public API ---

/// Check whether a commit should be rate-limited.
///
/// Returns `RateLimitOutcome::Allowed` if the commit is under all configured
/// limits, or `RateLimitOutcome::Exceeded` with details of the first violated
/// limit.
///
/// The `user_filter` parameter should be `Some(username)` when the config is
/// per-user, allowing the caller to scope ancestor counting to commits by a
/// specific author. Pass `None` for global (non-per-user) configs.
pub async fn check_commit_rate_limit(
    ctx: &CoreContext,
    repo: &impl Repo,
    bookmark: &BookmarkKey,
    changeset: &BonsaiChangeset,
    config: &CommitRateLimitConfig,
    user_filter: Option<&str>,
    cache: Option<cache::ChangesetEligibilityCache>,
) -> Result<RateLimitOutcome> {
    if !touches_directories(changeset, &config.directories) {
        return Ok(RateLimitOutcome::Allowed);
    }
    if !is_eligible_for_rate_limit(&config.eligibility_checks, changeset) {
        return Ok(RateLimitOutcome::Allowed);
    }

    // Draft count is independent of the time window, so compute once.
    let draft_count = count_eligible_draft_ancestors(
        ctx,
        repo,
        bookmark,
        changeset,
        config,
        user_filter,
        cache.clone(),
    )
    .await?;

    for limit in &config.limits {
        let window = Duration::from_secs(limit.window_secs());
        let public_count = count_eligible_public_ancestors(
            ctx,
            repo,
            bookmark,
            window,
            config,
            user_filter,
            cache.clone(),
        )
        .await?;

        let total = public_count + draft_count;
        if total >= limit.max_commits() {
            return Ok(RateLimitOutcome::Exceeded {
                total,
                window_secs: limit.window_secs(),
                max_commits: limit.max_commits(),
            });
        }
    }

    Ok(RateLimitOutcome::Allowed)
}

// --- Private helpers ---

async fn count_eligible_public_ancestors(
    ctx: &CoreContext,
    repo: &impl Repo,
    bookmark: &BookmarkKey,
    window: Duration,
    config: &CommitRateLimitConfig,
    user_filter: Option<&str>,
    cache: Option<cache::ChangesetEligibilityCache>,
) -> Result<u64> {
    let bookmark_cs_id = repo
        .bookmarks()
        .get(ctx.clone(), bookmark, Freshness::MaybeStale)
        .await?;

    let bookmark_cs_id = match bookmark_cs_id {
        Some(id) => id,
        None => return Ok(0),
    };

    let until_timestamp = chrono::Utc::now().timestamp() - window.as_secs() as i64;

    let predicate = build_cached_ancestor_predicate(
        &config.eligibility_checks,
        &config.directories,
        user_filter,
        cache,
        &config.repo_name,
        &config.rate_limit_name,
    );

    let opts = AncestorFilterOptions {
        until_timestamp: Some(until_timestamp),
        descendants_of: None,
        exclude_changeset_and_ancestors: None,
    };

    matching_ancestors_stream(ctx, repo, bookmark_cs_id, opts, predicate)
        .await?
        .try_fold(0u64, |acc, _| async move { Ok(acc + 1) })
        .await
}

async fn count_eligible_draft_ancestors(
    ctx: &CoreContext,
    repo: &impl Repo,
    bookmark: &BookmarkKey,
    changeset: &BonsaiChangeset,
    config: &CommitRateLimitConfig,
    user_filter: Option<&str>,
    cache: Option<cache::ChangesetEligibilityCache>,
) -> Result<u64> {
    let bookmark_cs_id = repo
        .bookmarks()
        .get(ctx.clone(), bookmark, Freshness::MaybeStale)
        .await?;

    let common = match bookmark_cs_id {
        Some(id) => vec![id],
        None => vec![],
    };

    let current_cs_id = changeset.get_changeset_id();

    let stream = repo
        .commit_graph()
        .ancestors_difference_stream(ctx, vec![current_cs_id], common)
        .await?;

    let ctx = ctx.clone();
    let repo_blobstore = repo.repo_blobstore().clone();
    let checks = config.eligibility_checks.clone();
    let directories = config.directories.clone();
    let user_filter = user_filter.map(|u| u.to_owned());
    let stats_repo = config.repo_name.clone();
    let stats_rl = config.rate_limit_name.clone();

    stream
        .try_filter_map(move |cs_id| {
            let ctx = ctx.clone();
            let repo_blobstore = repo_blobstore.clone();
            let cache = cache.clone();
            let checks = checks.clone();
            let directories = directories.clone();
            let user_filter = user_filter.clone();
            let stats_repo = stats_repo.clone();
            let stats_rl = stats_rl.clone();
            async move {
                if cs_id == current_cs_id {
                    return Ok(None);
                }

                // When cache is available, check BEFORE loading from blobstore.
                // Cache hits skip the expensive cs_id.load() entirely.
                if let Some(ref cache) = cache {
                    if let Some(cached) = cache.lookup(&cs_id) {
                        STATS::eligibility_cache_draft_hit.add_value(1, (stats_repo, stats_rl));
                        let matches = cached
                            .as_ref()
                            .map(|i| matches_user_filter(i, user_filter.as_deref()))
                            .unwrap_or(false);
                        return if matches { Ok(Some(cs_id)) } else { Ok(None) };
                    }
                    STATS::eligibility_cache_draft_miss.add_value(1, (stats_repo, stats_rl));
                }

                // Cache miss or no cache: load from blobstore.
                let bonsai = cs_id.load(&ctx, &repo_blobstore).await?;
                let info = inspect_changeset_eligibility(&bonsai, &checks, &directories);

                if let Some(ref cache) = cache {
                    cache.insert(cs_id, info.clone());
                }

                let matches = info
                    .as_ref()
                    .map(|i| matches_user_filter(i, user_filter.as_deref()))
                    .unwrap_or(false);
                if matches { Ok(Some(cs_id)) } else { Ok(None) }
            }
        })
        .try_fold(0u64, |acc, _| async move { Ok(acc + 1) })
        .await
}

fn is_eligible_for_rate_limit(checks: &[EligibilityCheck], changeset: &BonsaiChangeset) -> bool {
    checks.iter().any(|check| check.is_eligible(changeset))
}

fn touches_directories(changeset: &BonsaiChangeset, directories: &[String]) -> bool {
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
fn inspect_changeset_eligibility(
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
fn matches_user_filter(info: &EligibleChangesetInfo, user_filter: Option<&str>) -> bool {
    match user_filter {
        None => true,
        Some(username) => info
            .parsed_username
            .as_deref()
            .map(|u| u == username)
            .unwrap_or(false),
    }
}

/// Build a predicate that uses the cache (if available) to avoid redundant
/// inspection. The cache is populated synchronously since `matching_ancestors_stream`
/// already loads the `BonsaiChangeset` before calling the predicate.
fn build_cached_ancestor_predicate(
    checks: &[EligibilityCheck],
    directories: &[String],
    user_filter: Option<&str>,
    cache: Option<cache::ChangesetEligibilityCache>,
    repo_name: &str,
    rate_limit_name: &str,
) -> Arc<dyn Fn(&BonsaiChangeset) -> bool + Send + Sync> {
    match cache {
        Some(cache) => {
            let checks = checks.to_vec();
            let directories = directories.to_vec();
            let user_filter = user_filter.map(|u| u.to_owned());
            let stats_repo = repo_name.to_owned();
            let stats_rl = rate_limit_name.to_owned();
            Arc::new(move |changeset: &BonsaiChangeset| {
                let cs_id = changeset.get_changeset_id();
                let info = cache.get_or_insert_with(
                    cs_id,
                    || {
                        STATS::eligibility_cache_public_hit
                            .add_value(1, (stats_repo.clone(), stats_rl.clone()));
                    },
                    || {
                        STATS::eligibility_cache_public_miss
                            .add_value(1, (stats_repo.clone(), stats_rl.clone()));
                        inspect_changeset_eligibility(changeset, &checks, &directories)
                    },
                );

                info.as_ref()
                    .map(|i| matches_user_filter(i, user_filter.as_deref()))
                    .unwrap_or(false)
            })
        }
        None => build_ancestor_predicate(checks, directories, user_filter),
    }
}

fn build_ancestor_predicate(
    checks: &[EligibilityCheck],
    directories: &[String],
    user_filter: Option<&str>,
) -> Arc<dyn Fn(&BonsaiChangeset) -> bool + Send + Sync> {
    let checks = checks.to_vec();
    let directories = directories.to_vec();
    let user_filter = user_filter.map(|u| u.to_owned());

    Arc::new(move |changeset: &BonsaiChangeset| {
        let info = match inspect_changeset_eligibility(changeset, &checks, &directories) {
            Some(info) => info,
            None => return false,
        };
        matches_user_filter(&info, user_filter.as_deref())
    })
}

/// Extract the username from an author string of the form "Name <user@host>".
///
/// Returns `Some(username)` where username is the part before `@` in the email,
/// or `None` if the author string does not match the expected format.
fn parse_author_username(author: &str) -> Option<&str> {
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
