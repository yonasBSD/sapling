/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::marker::PhantomData;
use std::pin::Pin;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::thread;
use std::thread::JoinHandle;
use std::time::Duration;

use anyhow::ensure;

use crate::ResolvedBacktraceProcessFunc;
use crate::frame_handler;
use crate::frame_handler::FramePayload;
use crate::frame_handler::RING_BUF_SIZE;
use crate::osutil;
use crate::ring_buffer;
use crate::signal_handler;
use crate::signal_handler::SignalState;

/// Represents a profiling configuration for the owning thread.
/// Contains resources (ring buffer, thread handle) allocated.
/// Dropping this struct stops the profiler.
pub struct Profiler {
    /// Pinned because the signal handler holds a raw pointer to this.
    signal_state: Pin<Box<SignalState>>,
    /// Combined timer + frame-reader thread.
    handle: Option<JoinHandle<()>>,
    /// Shared stop flag — set in `drop()`, checked by profiler thread.
    stop: Arc<AtomicBool>,
    // Unimplement Send+Sync.
    // This avoids tricky race conditions during "stop".
    // Without this, a race condition might look like:
    // 1. [thread 1] Start profiling for thread 1.
    // 2. [thread 1] Enter signal handler. Before writing to ring buffer.
    // 3. [thread 2] Stop profiling. Close the ring buffer writer.
    // 4. [thread 1] Write to ring buffer — push returns false, backtrace dropped.
    // If the profiling for thread 1 can only be stopped by thread 1,
    // then the stop logic can block the signal first, guaranteeing the
    // signal handler isn't (and won't) run.
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

        let (writer, reader) = ring_buffer::ring_buffer::<FramePayload, RING_BUF_SIZE>();
        let stop = Arc::new(AtomicBool::new(false));

        let thread_id = osutil::get_thread_id();

        osutil::setup_signal_handler(SIG, signal_handler::signal_handler)?;
        osutil::unblock_signal(SIG);

        let signal_state = Box::pin(SignalState { writer });

        // Cast to usize to cross the thread boundary (raw pointers aren't Send).
        // Safety: the pointee (Pin<Box<SignalState>>) outlives the profiler
        // thread, which is joined in Profiler::drop.
        let signal_state_addr = &*signal_state as *const SignalState as usize;

        let handle = thread::Builder::new()
            .name(format!("profiler-{thread_id:?}"))
            .spawn({
                let stop = stop.clone();
                move || {
                    frame_handler::profiler_loop(
                        reader,
                        SIG,
                        thread_id,
                        interval,
                        signal_state_addr,
                        stop,
                        backtrace_process_func,
                    );
                }
            })?;

        Ok(Self {
            signal_state,
            handle: Some(handle),
            stop,
            _marker: PhantomData,
        })
    }
}

impl Drop for Profiler {
    fn drop(&mut self) {
        // Prevent new signal handler invocations on this thread.
        osutil::block_signal(SIG);
        // Tell the profiler thread to stop and prevent further pushes.
        self.stop.store(true, Ordering::Release);
        self.signal_state.writer.close();
        // Wake up and wait the profiler thread.
        if let Some(handle) = self.handle.take() {
            handle.thread().unpark();
            let _ = handle.join();
        }
        // Catch any SIGPROF the profiler thread sent between our block_signal
        // and its exit.
        osutil::drain_pending_signals(SIG);
        // Restore signal.
        osutil::unblock_signal(SIG);
    }
}
