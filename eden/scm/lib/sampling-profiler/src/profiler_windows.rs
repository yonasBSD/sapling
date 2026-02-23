/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::marker::PhantomData;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::thread;
use std::thread::JoinHandle;
use std::time::Duration;

use backtrace_ext::ThreadHandle;
use backtrace_ext::trace_remote_thread;

use crate::ResolvedBacktraceProcessFunc;

/// Sampling profiler for Windows.
///
/// Periodically suspends the target thread, captures its stack via
/// `trace_remote_thread`, resolves symbols, and invokes the callback.
pub struct Profiler {
    stop_flag: Arc<AtomicBool>,
    handle: Option<JoinHandle<()>>,
    // !Send+!Sync: must be dropped on the creating thread (same rationale as Unix).
    _marker: PhantomData<*const ()>,
}

impl Profiler {
    /// Start profiling the current thread at `interval`.
    pub fn new(
        interval: Duration,
        mut backtrace_process_func: ResolvedBacktraceProcessFunc,
    ) -> anyhow::Result<Self> {
        let thread_handle = ThreadHandle::current_thread()?;
        let stop_flag = Arc::new(AtomicBool::new(false));

        let handle = thread::Builder::new()
            .name("profiler-sampler".into())
            .spawn({
                let stop_flag = stop_flag.clone();
                move || {
                    while !stop_flag.load(Ordering::Acquire) {
                        thread::park_timeout(interval);
                        if stop_flag.load(Ordering::Acquire) {
                            break;
                        }

                        let frames = trace_remote_thread(&thread_handle);
                        if frames.is_empty() {
                            continue;
                        }

                        // Resolve after resume (trace_remote_thread already resumed).
                        let names: Vec<String> = frames.iter().map(|f| f.resolve()).collect();
                        backtrace_process_func(&names);
                    }
                }
            })?;

        Ok(Self {
            stop_flag,
            handle: Some(handle),
            _marker: PhantomData,
        })
    }
}

impl Drop for Profiler {
    fn drop(&mut self) {
        self.stop_flag.store(true, Ordering::Release);
        if let Some(handle) = self.handle.take() {
            handle.thread().unpark();
            let _ = handle.join();
        }
    }
}
