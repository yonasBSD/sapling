/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::thread;
use std::time::Duration;
use std::time::Instant;

use crate::Profiler;

#[test]
fn test_stress_concurrent_profilers() {
    // Repeat to surface intermittent hangs or crashes.

    // Note: each "Profiler" might spawn 1 to 2 threads.
    // Total: JOBS * INTERVALS.len() * (2 or 3) threads.
    let (jobs, iterations, intervals) = if cfg!(debug_assertions) {
        (4, 30, &[2][..])
    } else {
        (12, 50, &[2, 1, 0, 5][..])
    };

    let handles: Vec<_> = (0..jobs)
        .map(|i| {
            thread::spawn(move || {
                for j in 0..iterations {
                    eprintln!("Thread #{i}: Iteration {j}");
                    let mut profilers: Vec<_> = intervals
                        .iter()
                        .map(|&ms| {
                            Profiler::new(
                                Duration::from_millis(ms),
                                Box::new(move |_frames: &[String]| {}),
                            )
                            .unwrap()
                        })
                        .collect();

                    // Rust stdlib has assertion on "errno" (some libc function seems to use errno
                    // instead of a local state). This sleep might exercise the errno save/restore
                    // logic in the signal handler.
                    // https://github.com/rust-lang/rust/blob/5dbaac135785bca7152c5809430b1fb1653db8b1/library/std/src/sys/thread/unix.rs#L590
                    thread::sleep(Duration::from_millis(64));

                    // Try different drop orders.
                    for _ in 1..profilers.len() {
                        profilers.remove((i + j) % profilers.len());
                    }
                    drop(profilers);
                }
                eprintln!("Thread #{i}: Completed");
            })
        })
        .collect();
    for h in handles {
        h.join().unwrap();
    }
}

/// Stress test about malloc use-cases (which uses locks internally) where
/// libc::write in the signal handler can deadlock if the pipe is blocking.
///
/// Example deadlock: The profiled thread holds a jemalloc mutex
/// (mid-allocation) when SIGPROF fires. The signal handler tries to `write()`
/// to the pipe, but the pipe is full. The consumer can't drain the pipe because
/// it's also trying to allocate (symbol resolution) and blocks on the same
/// jemalloc mutex.
///
/// Ingredients: (1) signal fires during malloc, (2) pipe buffer is full,
/// (3) consumer is blocked on the same allocator lock.
#[test]
fn test_signal_during_malloc_deadlock() {
    use std::sync::Arc;
    use std::sync::atomic::AtomicBool;
    use std::sync::atomic::Ordering;

    let stop = Arc::new(AtomicBool::new(false));

    let worker = thread::spawn({
        let stop = stop.clone();
        move || {
            let _profiler = Profiler::new(
                Duration::from_millis(1),
                Box::new(|_: &[String]| {
                    // Allocation-heavy callback slows the consumer, filling the
                    // pipe and increasing jemalloc lock contention — both required
                    // ingredients for the deadlock.
                    let mut v = Vec::new();
                    for i in 0..200 {
                        v.push(vec![0u8; 512 * (i + 1)]);
                    }
                }),
            )
            .unwrap();

            // Churn allocations so SIGPROF likely fires inside jemalloc.
            while !stop.load(Ordering::Relaxed) {
                let mut bufs: Vec<Vec<u8>> = Vec::with_capacity(256);
                for size in (1..=128).map(|i| i * 512) {
                    bufs.push(vec![0u8; size]);
                }
                while bufs.len() > 1 {
                    bufs.swap_remove(bufs.len() / 2);
                }
            }
            // _profiler drops here. If deadlocked, we never reach this point.
        }
    });

    // Let the workload run under profiling pressure.
    thread::sleep(Duration::from_secs(3));
    stop.store(true, Ordering::Relaxed);

    // If the worker (or its Profiler::drop) is deadlocked, it won't finish.
    let deadline = Instant::now() + Duration::from_secs(5);
    while !worker.is_finished() {
        assert!(
            Instant::now() < deadline,
            "deadlock: signal handler write blocked while consumer waits on allocator lock"
        );
        thread::sleep(Duration::from_millis(200));
    }
    worker.join().unwrap();
}
