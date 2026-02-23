/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::marker::PhantomData;
use std::pin::Pin;
use std::thread;
use std::thread::JoinHandle;
use std::time::Duration;

use anyhow::ensure;

use crate::ResolvedBacktraceProcessFunc;
use crate::frame_handler;
use crate::osutil;
use crate::signal_handler;
use crate::signal_handler::SignalState;

/// Represents a profiling configuration for the owning thread.
/// Contains resources (fd, thread handle) allocated.
/// Dropping this struct stops the profiler.
pub struct Profiler {
    /// Pinned because the signal handler holds a raw pointer to this.
    /// Owns the write end of the pipe (closed in `drop()` to trigger
    /// POLLHUP on the profiler thread).
    signal_state: Pin<Box<SignalState>>,
    /// Combined timer + frame-reader thread.
    handle: Option<JoinHandle<()>>,
    // Unimplement Send+Sync.
    // This avoids tricky race conditions during "stop".
    // Without this, a race condition might look like:
    // 1. [thread 1] Start profiling for thread 1.
    // 2. [thread 1] Enter signal handler. Before reading pipe fd.
    // 3. [thread 2] Stop profiling. Close the pipe fd.
    // 4. [thread ?] Create a new fd that happened to match the closed fd.
    // 5. [thread 1] Read pipe fd. Got the wrong fd.
    // If the profiling for thread 1 can only be stopped by thread 1,
    // then the stop logic can stop the timer, assume the signal handler isn't
    // (and won't) run, then close the fd.
    _marker: PhantomData<*const ()>,
}

const SIG: i32 = libc::SIGPROF;

impl Profiler {
    /// Start profiling the current thread with the given interval.
    /// `backtrace_process_func` is a callback to receive resolved frames
    /// (most recent call first).
    pub fn new(
        interval: Duration,
        backtrace_process_func: ResolvedBacktraceProcessFunc,
    ) -> anyhow::Result<Self> {
        ensure!(
            interval >= Duration::from_millis(1),
            "minimal interval is 1ms to avoid starving threads"
        );

        let [read_fd, write_fd] = osutil::setup_pipe()?;

        let thread_id = osutil::get_thread_id();

        osutil::setup_signal_handler(SIG, signal_handler::signal_handler)?;
        osutil::unblock_signal(SIG);

        let signal_state = Box::pin(SignalState { write_fd });

        // Cast to usize to cross the thread boundary (raw pointers aren't Send).
        // Safety: the pointee (Pin<Box<SignalState>>) outlives the profiler
        // thread, which is joined in Profiler::drop.
        let signal_state_addr = &*signal_state as *const SignalState as usize;

        let handle = thread::Builder::new()
            .name(format!("profiler-{thread_id:?}"))
            .spawn(move || {
                frame_handler::profiler_loop(
                    read_fd,
                    SIG,
                    thread_id,
                    interval,
                    signal_state_addr,
                    backtrace_process_func,
                );
            })?;

        Ok(Self {
            signal_state,
            handle: Some(handle),
            _marker: PhantomData,
        })
    }
}

impl Drop for Profiler {
    fn drop(&mut self) {
        // Prevent new signal handler invocations on this thread.
        osutil::block_signal(SIG);
        // Close the write end — POLLHUP wakes the profiler thread, which
        // stops sending signals and exits.
        self.signal_state.write_fd.close();
        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
        // Catch any SIGPROF the profiler thread sent between our block_signal
        // and its exit.
        osutil::drain_pending_signals(SIG);
        // Restore signal.
        osutil::unblock_signal(SIG);
    }
}
