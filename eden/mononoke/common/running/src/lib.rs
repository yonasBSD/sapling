/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::future::Future;
use std::sync::Arc;
use std::sync::atomic::AtomicI64;
use std::time::Duration;

use anyhow::Error;
use anyhow::Result;
use futures::TryFutureExt;
use futures::future;
use futures::future::Either;
use mononoke_macros::mononoke;
use tokio::signal::unix::SignalKind;
use tokio::signal::unix::signal;
use tokio::time;
use tracing::error;
use tracing::info;

/// A shutdown grace period that can be resolved lazily.
///
/// This allows the grace period to be determined at shutdown time (when the
/// termination signal is received) rather than at server startup. For example,
/// a JustKnob can be read when SIGTERM arrives, allowing oncall to reduce the
/// grace period during a SEV without restarting the server.
///
/// `Duration` implements this trait directly, so callers that use a fixed
/// grace period require no changes.
pub trait ShutdownGracePeriod: Send {
    fn resolve(&self) -> Duration;
}

impl ShutdownGracePeriod for Duration {
    fn resolve(&self) -> Duration {
        *self
    }
}

/// Run a server future, and wait until a termination signal is received.
///
/// When the termination signal is received, the `quiesce` callback is called.
/// This should perform any steps required to quiesce the server, for example
/// by removing this instance from routing configuration, or asking the load
/// balancer to stop sending requests to this instance.  Requests that do
/// arrive should still be accepted.
///
/// After the configured quiesce timeout, the `shutdown` future is awaited.
/// This should do any additional work to stop accepting connections and wait
/// until all outstanding requests have been handled. The `server` future
/// continues to run while `shutdown` is being awaited.
///
/// Once both `shutdown` and `server` have completed, the process
/// exits. If `shutdown_timeout` is exceeded, the server process is canceled
/// and an error is returned.
pub async fn run_until_terminated<Server, QuiesceFn, ShutdownFut>(
    server: Server,
    quiesce: QuiesceFn,
    shutdown_grace_period: impl ShutdownGracePeriod,
    shutdown: ShutdownFut,
    shutdown_timeout: Duration,
    requests_counter: Option<Arc<AtomicI64>>,
) -> Result<(), Error>
where
    Server: Future<Output = Result<(), Error>> + Send + 'static,
    QuiesceFn: FnOnce(),
    ShutdownFut: Future<Output = ()>,
{
    // We want to prevent Folly's signal handlers overriding our
    // intended action with a termination signal. Mononoke server,
    // in particular, depends on this - otherwise our attempts to
    // catch and handle SIGTERM turn into Folly backtracing and killing us.
    unsafe {
        libc::signal(libc::SIGTERM, libc::SIG_DFL);
    }

    let mut terminate = signal(SignalKind::terminate())?;
    let mut interrupt = signal(SignalKind::interrupt())?;

    let terminate = terminate.recv();
    let interrupt = interrupt.recv();
    futures::pin_mut!(terminate, interrupt);

    // This future becomes ready when we receive a termination signal
    let signalled = future::select(terminate, interrupt);

    // Spawn the server onto its own task
    let server_handle = mononoke::spawn_task(server);

    // Now wait for the termination signal, or a server exit.
    let server_result_or_handle = match future::select(server_handle, signalled).await {
        Either::Left((server_result, _)) => {
            let server_result = server_result.map_err(Error::from).and_then(|res| res);
            match server_result.as_ref() {
                Ok(()) => {
                    error!("Server has exited! Starting shutdown...");
                }
                Err(e) => {
                    error!(
                        "Server exited with an error! Starting shutdown... Error: {:?}",
                        e
                    );
                }
            }
            Either::Left(server_result)
        }
        Either::Right((_, server_handle)) => {
            info!("Signalled! Starting shutdown...");
            Either::Right(server_handle)
        }
    };

    // Shutting down: wait for the grace period.
    quiesce();

    let wait_start = std::time::Instant::now();
    if let Some(requests_counter) = requests_counter {
        loop {
            let grace_period = shutdown_grace_period.resolve();
            let requests_in_flight = requests_counter.load(std::sync::atomic::Ordering::Relaxed);
            let waited = std::time::Instant::now() - wait_start;

            match (waited, requests_in_flight) {
                (_, req) if req <= 0 => {
                    info!("No requests still in flight!");
                    break;
                }
                (waited, req) if waited > grace_period => {
                    info!(
                        "Still {} requests in flight but we already waited {}s while the shutdown grace period is {}s. We're dropping the remaining requests.",
                        req,
                        waited.as_secs(),
                        grace_period.as_secs(),
                    );
                    break;
                }
                (_, req) => {
                    info!(
                        "Still {} requests in flight. Waiting (grace period: {}s)",
                        req,
                        grace_period.as_secs(),
                    );
                }
            }

            time::sleep(Duration::from_secs(5)).await;
        }
    } else {
        let grace_period = shutdown_grace_period.resolve();
        info!(
            "Waiting {}s before shutting down server",
            grace_period.as_secs(),
        );
        time::sleep(grace_period).await;
    }

    let shutdown = async move {
        shutdown.await;
        match server_result_or_handle {
            Either::Left(server_result) => server_result,
            Either::Right(server_handle) => server_handle.await?,
        }
    };

    info!("Shutting down...");
    time::timeout(shutdown_timeout, shutdown)
        .map_err(|_| Error::msg("Timed out shutting down server"))
        .await?
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::AtomicU64;
    use std::sync::atomic::Ordering;

    use super::*;

    #[mononoke::test]
    fn test_duration_implements_shutdown_grace_period() {
        let d = Duration::from_secs(30);
        assert_eq!(d.resolve(), Duration::from_secs(30));
        // Can be called multiple times
        assert_eq!(d.resolve(), Duration::from_secs(30));
    }

    #[mononoke::test]
    fn test_zero_duration_grace_period() {
        let d = Duration::from_secs(0);
        assert_eq!(d.resolve(), Duration::ZERO);
    }

    struct CountingGracePeriod {
        value: Duration,
        call_count: Arc<AtomicU64>,
    }

    impl ShutdownGracePeriod for CountingGracePeriod {
        fn resolve(&self) -> Duration {
            self.call_count.fetch_add(1, Ordering::SeqCst);
            self.value
        }
    }

    #[mononoke::test]
    fn test_custom_grace_period_is_called() {
        let count = Arc::new(AtomicU64::new(0));
        let gp = CountingGracePeriod {
            value: Duration::from_secs(60),
            call_count: count.clone(),
        };
        assert_eq!(gp.resolve(), Duration::from_secs(60));
        assert_eq!(gp.resolve(), Duration::from_secs(60));
        assert_eq!(count.load(Ordering::SeqCst), 2);
    }

    struct MutableGracePeriod {
        secs: Arc<AtomicU64>,
    }

    impl ShutdownGracePeriod for MutableGracePeriod {
        fn resolve(&self) -> Duration {
            Duration::from_secs(self.secs.load(Ordering::SeqCst))
        }
    }

    #[mononoke::test]
    fn test_dynamic_grace_period_reflects_changes() {
        let secs = Arc::new(AtomicU64::new(1800));
        let gp = MutableGracePeriod { secs: secs.clone() };

        assert_eq!(gp.resolve(), Duration::from_secs(1800));

        secs.store(60, Ordering::SeqCst);
        assert_eq!(gp.resolve(), Duration::from_secs(60));

        secs.store(0, Ordering::SeqCst);
        assert_eq!(gp.resolve(), Duration::ZERO);
    }

    #[tokio::test]
    async fn test_run_until_terminated_respects_dynamic_grace_period() {
        let secs = Arc::new(AtomicU64::new(0));
        let gp = MutableGracePeriod { secs: secs.clone() };
        let counter = Arc::new(AtomicI64::new(5));
        let counter_clone = counter.clone();

        // Server that immediately exits
        let server = async { Ok(()) };

        // Set grace period to 0 so drain loop exits immediately
        secs.store(0, Ordering::SeqCst);

        let result = run_until_terminated(
            server,
            || {},
            gp,
            async {},
            Duration::from_secs(5),
            Some(counter_clone),
        )
        .await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_run_until_terminated_exits_when_no_requests() {
        let counter = Arc::new(AtomicI64::new(0));
        let counter_clone = counter.clone();

        let server = async { Ok(()) };

        let result = run_until_terminated(
            server,
            || {},
            Duration::from_secs(300),
            async {},
            Duration::from_secs(5),
            Some(counter_clone),
        )
        .await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_run_until_terminated_without_counter() {
        let server = async { Ok(()) };

        let result = run_until_terminated(
            server,
            || {},
            Duration::from_secs(0),
            async {},
            Duration::from_secs(5),
            None,
        )
        .await;

        assert!(result.is_ok());
    }
}
