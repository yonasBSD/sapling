/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::sync::Arc;
use std::sync::atomic::AtomicUsize;
use std::sync::atomic::Ordering;
use std::time::Instant;

use anyhow::Result;
use bytes::Bytes;
use cached_config::ConfigHandle;
use cached_config::ConfigStore;
use gotham::helpers::http::Body;
use gotham::state::FromState;
use gotham::state::State;
use gotham_derive::StateData;
use gotham_ext::middleware::Middleware;
use http::HeaderMap;
use http::Method;
use http::Response;
use http::Uri;
use http_body_util::BodyExt as _;
use regex::Regex;
use shadow_traffic_config::ShadowTrafficConfig;
use stats::prelude::*;
use tracing::debug;
use tracing::warn;

define_stats! {
    prefix = "mononoke.shadow";
    skipped_disabled: timeseries(Rate, Sum),
    skipped_sample: timeseries(Rate, Sum),
    skipped_path: timeseries(Rate, Sum),
    skipped_backpressure: timeseries(Rate, Sum),
    skipped_is_shadow: timeseries(Rate, Sum),
    received: timeseries(Rate, Sum),
    eligible: timeseries(Rate, Sum),
    forwarded: timeseries(Rate, Sum),
    forward_success: timeseries(Rate, Sum),
    forward_failure: timeseries(Rate, Sum),
    forward_duration_ms: histogram(1, 0, 10_000, Average, Sum, Count; P 50; P 95; P 99),
}

pub const SHADOW_HEADER: &str = "x-mononoke-shadow";

/// Headers to forward from the original request to the shadow server
/// so the shadow can identify and authorize the client.
const FORWARDED_HEADERS: &[&str] = &[
    "x-fb-validated-client-encoded-identity",
    "tfb-orig-client-ip",
    "tfb-orig-client-port",
    "x-client-info",
];

/// Stores the request body bytes captured during inbound, so outbound
/// can include them in the forwarded request. The handler consumes the
/// original body from State, so we must capture it before that happens.
#[derive(StateData)]
struct ShadowRequestBody(Bytes);

pub struct ShadowForwarderMiddleware {
    /// None when config is missing — middleware is disabled but server still starts.
    config_handle: Option<ConfigHandle<ShadowTrafficConfig>>,
    /// Tracks in-flight shadow requests. Compared against the live
    /// config value of semaphore_permits on each request, so changes
    /// to the config take effect immediately without restart.
    inflight: Arc<AtomicUsize>,
    http_client: reqwest::Client,
    cached_include: std::sync::RwLock<CachedRegex>,
    cached_exclude: std::sync::RwLock<CachedRegex>,
    /// When true, this instance is a shadow tier and should never forward.
    /// Set via --shadow-tier CLI flag.
    is_shadow_tier: bool,
}

// request::Client contains dyn trait objects that don't impl RefUnwindSafe,
// but the client is safe to use across unwind boundaries — it's just an
// HTTP connection pool. std::sync::RwLock is RefUnwindSafe.
impl std::panic::RefUnwindSafe for ShadowForwarderMiddleware {}

struct CachedRegex {
    pattern: String,
    compiled: Option<Regex>,
}

impl CachedRegex {
    fn new() -> Self {
        Self {
            pattern: String::new(),
            compiled: None,
        }
    }

    fn get_or_compile(&mut self, pattern: &str) -> Option<&Regex> {
        if self.pattern != pattern {
            self.pattern = pattern.to_string();
            self.compiled = if pattern.is_empty() {
                None
            } else {
                match Regex::new(pattern) {
                    Ok(r) => Some(r),
                    Err(e) => {
                        warn!(
                            pattern = %pattern,
                            error = %e,
                            "Shadow forwarder: invalid regex pattern in config",
                        );
                        None
                    }
                }
            };
        }
        self.compiled.as_ref()
    }
}

impl ShadowForwarderMiddleware {
    pub fn new(
        config_store: &ConfigStore,
        config_path: &str,
        is_shadow_tier: bool,
    ) -> Result<Self> {
        let config_handle =
            match config_store.get_config_handle::<ShadowTrafficConfig>(config_path.to_string()) {
                Ok(handle) => Some(handle),
                Err(e) => {
                    warn!(
                        config_path = %config_path,
                        error = %e,
                        "Shadow forwarder: config not found, middleware disabled",
                    );
                    None
                }
            };

        let http_client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()?;

        Ok(Self {
            config_handle,
            inflight: Arc::new(AtomicUsize::new(0)),
            http_client,
            cached_include: std::sync::RwLock::new(CachedRegex::new()),
            cached_exclude: std::sync::RwLock::new(CachedRegex::new()),
            is_shadow_tier,
        })
    }

    fn path_matches_include(&self, path: &str, pattern: &str) -> bool {
        if pattern.is_empty() {
            return true;
        }
        let mut cache = self.cached_include.write().expect("poisoned lock");
        cache
            .get_or_compile(pattern)
            .is_some_and(|re| re.is_match(path))
    }
    fn path_matches_exclude(&self, path: &str, pattern: &str) -> bool {
        if pattern.is_empty() {
            return false;
        }
        let mut cache = self.cached_exclude.write().expect("poisoned lock");
        cache
            .get_or_compile(pattern)
            .is_some_and(|re| re.is_match(path))
    }

    /// Extract identity headers from the request state for forwarding.
    fn extract_forwarding_headers(state: &State) -> reqwest::header::HeaderMap {
        let mut forwarding = reqwest::header::HeaderMap::new();
        if let Some(headers) = HeaderMap::try_borrow_from(state) {
            for &name in FORWARDED_HEADERS {
                if let Some(value) = headers.get(name) {
                    if let (Ok(name), Ok(val)) = (
                        reqwest::header::HeaderName::from_bytes(name.as_bytes()),
                        reqwest::header::HeaderValue::from_bytes(value.as_bytes()),
                    ) {
                        forwarding.insert(name, val);
                    }
                }
            }
        }
        forwarding
    }
}

#[async_trait::async_trait]
impl Middleware for ShadowForwarderMiddleware {
    async fn inbound(&self, state: &mut State) -> Option<Response<Body>> {
        // Track shadow requests received on this tier
        if let Some(headers) = HeaderMap::try_borrow_from(state) {
            if headers.contains_key(SHADOW_HEADER) {
                STATS::received.add_value(1);
            }
        }

        // Capture the request body for later forwarding in outbound.
        // The handler will consume the body from State, so we take it now,
        // read the bytes, store a copy, and put a new body back.
        if !self.is_shadow_tier {
            let enabled = self
                .config_handle
                .as_ref()
                .map_or(false, |h| h.get().enabled);
            if enabled {
                if let Some(body) = state.try_take::<Body>() {
                    let body_bytes = body
                        .collect()
                        .await
                        .map(|collected| collected.to_bytes())
                        .unwrap_or_default();
                    state.put(ShadowRequestBody(body_bytes.clone()));
                    // Put a new body back so the handler can still consume it
                    use gotham::handler::IntoBody as _;
                    state.put(body_bytes.into_body());
                }
            }
        }

        None
    }

    async fn outbound(&self, state: &mut State, _response: &mut Response<Body>) {
        // Shadow tiers never forward
        if self.is_shadow_tier {
            return;
        }

        // Loop prevention: never forward requests that already have the shadow header
        if let Some(headers) = HeaderMap::try_borrow_from(state) {
            if headers.contains_key(SHADOW_HEADER) {
                STATS::skipped_is_shadow.add_value(1);
                return;
            }
        }

        let config_handle = match &self.config_handle {
            Some(h) => h,
            None => return,
        };
        let config: Arc<ShadowTrafficConfig> = config_handle.get();

        if !config.enabled {
            STATS::skipped_disabled.add_value(1);
            return;
        }

        let sample_percent = if config.sample_ratio > 0 {
            config.sample_ratio.min(100)
        } else {
            STATS::skipped_disabled.add_value(1);
            return;
        };

        if rand::random::<u64>() % 100 >= (sample_percent as u64) {
            STATS::skipped_sample.add_value(1);
            return;
        }

        let path = match Uri::try_borrow_from(state) {
            Some(uri) => uri
                .path_and_query()
                .map(|pq| pq.as_str().to_string())
                .unwrap_or_else(|| uri.path().to_string()),
            None => return,
        };

        if !self.path_matches_include(&path, &config.path_include) {
            STATS::skipped_path.add_value(1);
            return;
        }

        if self.path_matches_exclude(&path, &config.path_exclude) {
            STATS::skipped_path.add_value(1);
            return;
        }

        let target_url = &config.target_url;
        if target_url.is_empty() {
            return;
        }

        STATS::eligible.add_value(1);

        // Dynamic backpressure: compare inflight count against live config value
        let max_inflight = config.semaphore_permits.max(1) as usize;
        let current = self.inflight.fetch_add(1, Ordering::Relaxed);
        if current >= max_inflight {
            self.inflight.fetch_sub(1, Ordering::Relaxed);
            STATS::skipped_backpressure.add_value(1);
            return;
        }

        let url = format!("{}{}", target_url, path);
        let client = self.http_client.clone();
        let method = Method::try_borrow_from(state)
            .cloned()
            .unwrap_or(Method::GET);
        let fwd_headers = Self::extract_forwarding_headers(state);
        let body_bytes = state
            .try_take::<ShadowRequestBody>()
            .map(|b| b.0)
            .unwrap_or_default();
        let inflight = self.inflight.clone();

        STATS::forwarded.add_value(1);
        mononoke_macros::mononoke::spawn_task(async move {
            let start = Instant::now();
            let result = client
                .request(method, &url)
                .header(SHADOW_HEADER, "1")
                .headers(fwd_headers)
                .body(body_bytes)
                .send()
                .await;

            let duration_ms = start.elapsed().as_millis() as i64;
            STATS::forward_duration_ms.add_value(duration_ms);

            match result {
                Ok(resp) if resp.status().is_success() => {
                    STATS::forward_success.add_value(1);
                }
                Ok(resp) => {
                    STATS::forward_failure.add_value(1);
                    debug!(
                        url = %url,
                        status = %resp.status(),
                        "Shadow forward non-success",
                    );
                }
                Err(e) => {
                    STATS::forward_failure.add_value(1);
                    warn!(
                        url = %url,
                        error = %e,
                        "Shadow forward failed",
                    );
                }
            }

            inflight.fetch_sub(1, Ordering::Relaxed);
        });
    }
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddr;

    use cached_config::ModificationTime;
    use cached_config::TestSource;
    use gotham::handler::IntoBody as _;
    use http::Request;
    use mononoke_macros::mononoke;

    use super::*;

    fn make_config(
        enabled: bool,
        sample_ratio: i64,
        path_include: &str,
        path_exclude: &str,
    ) -> String {
        format!(
            r#"{{
                "enabled": {},
                "sample_ratio": {},
                "path_include": "{}",
                "path_exclude": "{}",
                "target_url": "https://shadow.example.com",
                "semaphore_permits": 100,
                "shadow_first_timeout_ms": 5000,
                "shadow_first": false
            }}"#,
            enabled, sample_ratio, path_include, path_exclude,
        )
    }

    fn make_test_middleware_with_shadow(
        enabled: bool,
        sample_ratio: i64,
        path_include: &str,
        path_exclude: &str,
        is_shadow_tier: bool,
    ) -> ShadowForwarderMiddleware {
        let test_source = TestSource::new();
        test_source.insert_config(
            "test/shadow_traffic",
            &make_config(enabled, sample_ratio, path_include, path_exclude),
            ModificationTime::UnixTimestamp(0),
        );
        let config_store = ConfigStore::new(Arc::new(test_source), None, None);
        ShadowForwarderMiddleware::new(&config_store, "test/shadow_traffic", is_shadow_tier)
            .unwrap()
    }

    fn make_test_middleware(
        enabled: bool,
        sample_ratio: i64,
        path_include: &str,
        path_exclude: &str,
    ) -> ShadowForwarderMiddleware {
        make_test_middleware_with_shadow(enabled, sample_ratio, path_include, path_exclude, false)
    }

    fn make_state(path: &str) -> State {
        let req = Request::builder().uri(path).body(Body::default()).unwrap();
        let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
        State::from_request(req, addr)
    }

    fn make_state_with_body(path: &str, method: &str, body: &[u8]) -> State {
        let req = Request::builder()
            .method(method)
            .uri(path)
            .body(body.to_vec().into_body())
            .unwrap();
        let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
        State::from_request(req, addr)
    }

    fn make_shadow_state(path: &str) -> State {
        let req = Request::builder()
            .uri(path)
            .header(SHADOW_HEADER, "1")
            .body(Body::default())
            .unwrap();
        let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
        State::from_request(req, addr)
    }

    fn make_response() -> Response<Body> {
        Response::builder()
            .status(200)
            .body(Body::default())
            .unwrap()
    }

    // --- Config tests ---

    #[mononoke::test]
    fn test_disabled_config() {
        let mw = make_test_middleware(false, 0, "", "");
        let config = mw.config_handle.as_ref().unwrap().get();
        assert!(!config.enabled);
        assert_eq!(config.sample_ratio, 0);
    }

    #[mononoke::test]
    fn test_enabled_config() {
        let mw = make_test_middleware(true, 100, "", "");
        let config = mw.config_handle.as_ref().unwrap().get();
        assert!(config.enabled);
        assert_eq!(config.sample_ratio, 100);
    }

    // --- Path filter tests ---

    #[mononoke::test]
    fn test_path_include_filter() {
        let mw = make_test_middleware(true, 10, "trees|files", "");
        assert!(mw.path_matches_include("/edenapi/trees", "trees|files"));
        assert!(mw.path_matches_include("/edenapi/files", "trees|files"));
        assert!(!mw.path_matches_include("/edenapi/commit", "trees|files"));
    }

    #[mononoke::test]
    fn test_path_include_empty_matches_all() {
        let mw = make_test_middleware(true, 10, "", "");
        assert!(mw.path_matches_include("/anything", ""));
    }

    #[mononoke::test]
    fn test_path_exclude_filter() {
        let mw = make_test_middleware(true, 10, "", "/upload/|/land/|/set_bookmark");
        assert!(mw.path_matches_exclude("/edenapi/upload/token", "/upload/|/land/|/set_bookmark"));
        assert!(mw.path_matches_exclude("/edenapi/land/v2", "/upload/|/land/|/set_bookmark"));
        assert!(!mw.path_matches_exclude("/edenapi/trees", "/upload/|/land/|/set_bookmark"));
    }

    #[mononoke::test]
    fn test_path_exclude_empty_matches_nothing() {
        let mw = make_test_middleware(true, 10, "", "");
        assert!(!mw.path_matches_exclude("/anything", ""));
    }

    #[mononoke::test]
    fn test_regex_caching() {
        let mw = make_test_middleware(true, 10, "", "");
        assert!(mw.path_matches_include("/foo", "foo|bar"));
        assert!(mw.path_matches_include("/bar", "foo|bar"));
        assert!(!mw.path_matches_include("/foo", "baz"));
    }

    #[mononoke::test]
    fn test_invalid_regex_returns_false() {
        let mw = make_test_middleware(true, 10, "", "");
        assert!(!mw.path_matches_include("/foo", "[invalid"));
        assert!(!mw.path_matches_exclude("/foo", "[invalid"));
    }

    #[mononoke::test]
    fn test_inflight_counter_starts_at_zero() {
        let mw = make_test_middleware(true, 10, "", "");
        assert_eq!(mw.inflight.load(Ordering::Relaxed), 0);
    }

    #[mononoke::test]
    fn test_negative_sample_ratio_treated_as_disabled() {
        let mw = make_test_middleware(true, -5, "", "");
        let config = mw.config_handle.as_ref().unwrap().get();
        assert!(config.sample_ratio < 0);
        // The outbound check `config.sample_ratio > 0` will skip forwarding
    }

    #[mononoke::test]
    fn test_default_path_exclude_blocks_mutations() {
        let mw = make_test_middleware(true, 100, "", "/upload/|/land/|/set_bookmark");
        assert!(mw.path_matches_exclude("/edenapi/upload/token", "/upload/|/land/|/set_bookmark"));
        assert!(mw.path_matches_exclude("/edenapi/land/v2", "/upload/|/land/|/set_bookmark"));
        assert!(mw.path_matches_exclude("/edenapi/set_bookmark", "/upload/|/land/|/set_bookmark"));
        assert!(!mw.path_matches_exclude("/edenapi/trees", "/upload/|/land/|/set_bookmark"));
        assert!(!mw.path_matches_exclude("/edenapi/files", "/upload/|/land/|/set_bookmark"));
    }

    // --- Outbound middleware logic tests ---

    #[mononoke::test]
    async fn test_outbound_disabled_skips() {
        let mw = make_test_middleware(false, 0, "", "");
        let mut state = make_state("/edenapi/trees");
        let mut response = make_response();
        mw.outbound(&mut state, &mut response).await;
    }

    #[mononoke::test]
    async fn test_outbound_zero_sample_ratio_skips() {
        let mw = make_test_middleware(true, 0, "", "");
        let mut state = make_state("/edenapi/trees");
        let mut response = make_response();
        mw.outbound(&mut state, &mut response).await;
    }

    #[mononoke::test]
    async fn test_outbound_excluded_path_skips() {
        let mw = make_test_middleware(true, 10, "", "/upload/|/land/");
        let mut response = make_response();
        for _ in 0..100 {
            let mut state = make_state("/edenapi/upload/token");
            mw.outbound(&mut state, &mut response).await;
        }
    }

    #[mononoke::test]
    async fn test_outbound_include_filter_blocks_non_matching() {
        let mw = make_test_middleware(true, 10, "trees", "");
        let mut response = make_response();
        for _ in 0..100 {
            let mut state = make_state("/edenapi/commit");
            mw.outbound(&mut state, &mut response).await;
        }
    }

    #[mononoke::test]
    async fn test_backpressure_with_low_permits() {
        let test_source = TestSource::new();
        test_source.insert_config(
            "test/shadow_traffic",
            r#"{
                    "enabled": true,
                    "sample_ratio": 100,
                    "path_include": "",
                    "path_exclude": "",
                    "target_url": "https://shadow.example.com",
                    "semaphore_permits": 1,
                    "shadow_first_timeout_ms": 5000,
                    "shadow_first": false
                }"#,
            ModificationTime::UnixTimestamp(0),
        );
        let config_store = ConfigStore::new(Arc::new(test_source), None, None);
        let mw =
            ShadowForwarderMiddleware::new(&config_store, "test/shadow_traffic", false).unwrap();

        // Simulate one inflight request
        mw.inflight.fetch_add(1, Ordering::Relaxed);
        // With semaphore_permits=1 and 1 already inflight, next should be skipped
        assert_eq!(mw.inflight.load(Ordering::Relaxed), 1);

        // Config says max 1, so any new request should hit backpressure
        let config = mw.config_handle.as_ref().unwrap().get();
        let max = config.semaphore_permits.max(1) as usize;
        assert_eq!(max, 1);
        assert!(mw.inflight.load(Ordering::Relaxed) >= max);
    }

    #[mononoke::test]
    fn test_sample_percent_clamped_to_100() {
        let mw = make_test_middleware(true, 200, "", "");
        let config = mw.config_handle.as_ref().unwrap().get();
        assert_eq!(config.sample_ratio, 200);
        assert_eq!(config.sample_ratio.min(100), 100);
    }

    #[mononoke::test]
    fn test_shadow_header_constant() {
        assert_eq!(SHADOW_HEADER, "x-mononoke-shadow");
    }

    // --- Body capture tests ---

    #[mononoke::test]
    async fn test_inbound_captures_body_when_enabled() {
        let mw = make_test_middleware(true, 100, "", "");
        let mut state = make_state_with_body("/edenapi/trees", "POST", b"request body data");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        // Body should be captured
        let captured = state.try_take::<ShadowRequestBody>();
        assert!(captured.is_some());
        assert_eq!(&captured.unwrap().0[..], b"request body data");
    }

    #[mononoke::test]
    async fn test_inbound_does_not_capture_body_when_disabled() {
        let mw = make_test_middleware(false, 0, "", "");
        let mut state = make_state_with_body("/edenapi/trees", "POST", b"request body data");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        // Body should NOT be captured when disabled
        let captured = state.try_take::<ShadowRequestBody>();
        assert!(captured.is_none());
    }

    #[mononoke::test]
    async fn test_inbound_does_not_capture_body_on_shadow_tier() {
        let mw = make_test_middleware_with_shadow(true, 100, "", "", true);
        let mut state = make_state_with_body("/edenapi/trees", "POST", b"request body data");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        // Shadow tier should NOT capture body
        let captured = state.try_take::<ShadowRequestBody>();
        assert!(captured.is_none());
    }

    #[mononoke::test]
    async fn test_inbound_replaces_body_for_handler() {
        let mw = make_test_middleware(true, 100, "", "");
        let mut state = make_state_with_body("/edenapi/trees", "POST", b"request body data");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        // The handler should still be able to consume the body
        let body = Body::try_take_from(&mut state);
        assert!(body.is_some());
    }

    // --- Loop prevention tests ---

    #[mononoke::test]
    async fn test_outbound_skips_shadow_requests() {
        let mw = make_test_middleware(true, 10, "", "");
        let mut state = make_shadow_state("/edenapi/trees");
        let mut response = make_response();
        mw.outbound(&mut state, &mut response).await;
    }

    #[mononoke::test]
    async fn test_outbound_shadow_request_never_forwards() {
        let mw = make_test_middleware(true, 10, "", "");
        let mut response = make_response();
        for _ in 0..100 {
            let mut state = make_shadow_state("/edenapi/trees");
            mw.outbound(&mut state, &mut response).await;
        }
    }

    #[mononoke::test]
    async fn test_inbound_tracks_shadow_requests() {
        let mw = make_test_middleware(true, 10, "", "");
        let mut state = make_shadow_state("/edenapi/trees");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
    }

    #[mononoke::test]
    async fn test_inbound_normal_request_no_tracking() {
        let mw = make_test_middleware(true, 10, "", "");
        let mut state = make_state("/edenapi/trees");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
    }

    // --- Shadow tier flag tests ---

    #[mononoke::test]
    async fn test_shadow_tier_never_forwards() {
        let mw = make_test_middleware_with_shadow(true, 100, "", "", true);
        let mut response = make_response();
        for _ in 0..100 {
            let mut state = make_state("/edenapi/trees");
            mw.outbound(&mut state, &mut response).await;
        }
    }

    #[mononoke::test]
    fn test_shadow_tier_flag_stored() {
        let mw = make_test_middleware_with_shadow(true, 10, "", "", true);
        assert!(mw.is_shadow_tier);

        let mw = make_test_middleware_with_shadow(true, 10, "", "", false);
        assert!(!mw.is_shadow_tier);
    }

    #[mononoke::test]
    async fn test_shadow_tier_still_tracks_received() {
        let mw = make_test_middleware_with_shadow(true, 10, "", "", true);
        let mut state = make_shadow_state("/edenapi/trees");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
    }

    // --- HTTP method forwarding tests ---

    #[mononoke::test]
    async fn test_outbound_preserves_get_method() {
        let mw = make_test_middleware(true, 100, "", "");
        let mut state = make_state("/edenapi/repos");
        let method = Method::try_borrow_from(&state).cloned();
        assert_eq!(method, Some(Method::GET));
        let mut response = make_response();
        mw.outbound(&mut state, &mut response).await;
    }

    #[mononoke::test]
    async fn test_outbound_preserves_post_method() {
        let mw = make_test_middleware(true, 100, "", "");
        let mut state = make_state_with_body("/edenapi/trees", "POST", b"body");
        let method = Method::try_borrow_from(&state).cloned();
        assert_eq!(method, Some(Method::POST));
        let mut response = make_response();
        mw.inbound(&mut state).await;
        mw.outbound(&mut state, &mut response).await;
    }

    // --- Identity header forwarding tests ---

    #[mononoke::test]
    fn test_extract_forwarding_headers_present() {
        let req = Request::builder()
            .uri("/test")
            .header("x-fb-validated-client-encoded-identity", "test-identity")
            .header("tfb-orig-client-ip", "1.2.3.4")
            .header("tfb-orig-client-port", "12345")
            .header("x-client-info", "{}")
            .body(Body::default())
            .unwrap();
        let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
        let state = State::from_request(req, addr);

        let headers = ShadowForwarderMiddleware::extract_forwarding_headers(&state);
        assert_eq!(
            headers
                .get("x-fb-validated-client-encoded-identity")
                .unwrap(),
            "test-identity"
        );
        assert_eq!(headers.get("tfb-orig-client-ip").unwrap(), "1.2.3.4");
        assert_eq!(headers.get("tfb-orig-client-port").unwrap(), "12345");
        assert_eq!(headers.get("x-client-info").unwrap(), "{}");
    }

    #[mononoke::test]
    fn test_extract_forwarding_headers_missing() {
        let state = make_state("/test");
        let headers = ShadowForwarderMiddleware::extract_forwarding_headers(&state);
        assert!(headers.is_empty());
    }

    #[mononoke::test]
    fn test_extract_forwarding_headers_partial() {
        let req = Request::builder()
            .uri("/test")
            .header("x-fb-validated-client-encoded-identity", "test-identity")
            .body(Body::default())
            .unwrap();
        let addr: SocketAddr = "127.0.0.1:8080".parse().unwrap();
        let state = State::from_request(req, addr);

        let headers = ShadowForwarderMiddleware::extract_forwarding_headers(&state);
        assert_eq!(headers.len(), 1);
        assert_eq!(
            headers
                .get("x-fb-validated-client-encoded-identity")
                .unwrap(),
            "test-identity"
        );
    }

    // --- Body edge case tests ---

    #[mononoke::test]
    async fn test_inbound_captures_empty_body() {
        let mw = make_test_middleware(true, 100, "", "");
        let mut state = make_state("/edenapi/repos");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        let captured = state.try_take::<ShadowRequestBody>();
        assert!(captured.is_some());
        assert!(captured.unwrap().0.is_empty());
    }

    // --- Missing config tests ---

    #[mononoke::test]
    fn test_new_with_missing_config_succeeds() {
        let test_source = TestSource::new();
        // No config inserted — path doesn't exist
        let config_store = ConfigStore::new(Arc::new(test_source), None, None);
        let mw = ShadowForwarderMiddleware::new(&config_store, "nonexistent/path", false);
        assert!(mw.is_ok());
        assert!(mw.unwrap().config_handle.is_none());
    }

    #[mononoke::test]
    async fn test_missing_config_inbound_is_noop() {
        let test_source = TestSource::new();
        let config_store = ConfigStore::new(Arc::new(test_source), None, None);
        let mw = ShadowForwarderMiddleware::new(&config_store, "nonexistent/path", false).unwrap();
        let mut state = make_state("/edenapi/trees");
        let result = mw.inbound(&mut state).await;
        assert!(result.is_none());
        // Body should NOT be captured (no config = disabled)
        let captured = state.try_take::<ShadowRequestBody>();
        assert!(captured.is_none());
    }

    #[mononoke::test]
    async fn test_missing_config_outbound_is_noop() {
        let test_source = TestSource::new();
        let config_store = ConfigStore::new(Arc::new(test_source), None, None);
        let mw = ShadowForwarderMiddleware::new(&config_store, "nonexistent/path", false).unwrap();
        let mut state = make_state("/edenapi/trees");
        let mut response = make_response();
        // Should not panic or forward anything
        mw.outbound(&mut state, &mut response).await;
    }
}
