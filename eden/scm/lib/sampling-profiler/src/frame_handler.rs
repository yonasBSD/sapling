/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::thread;
use std::time::Duration;
use std::time::Instant;

use backtrace_ext::Frame;

use crate::ResolvedBacktraceProcessFunc;
use crate::osutil::SIGNAL_PAYLOAD;
use crate::osutil::ThreadId;
use crate::ring_buffer::RingBufReader;
use crate::signal_handler::SignalState;

pub const RING_BUF_SIZE: usize = 4096;

/// `Frame` payload written to the ring buffer by the signal handler.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct FramePayload {
    /// Identity of a backtrace. Used to detect incomplete backtraces.
    pub backtrace_id: usize,
    /// Auto-incremental in a signal backtrace. Used to detect incomplete backtraces.
    pub depth: usize,
    pub frame: MaybeFrame,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub enum MaybeFrame {
    /// A frame is present.
    Present(Frame),
    /// No more frames for this backtrace.
    EndOfBacktrace,
}

/// Profiler loop: park → drain ring buffer → send signal.
///
/// The park duration is adjusted to account for symbol resolution overhead,
/// keeping signals approximately `interval` apart.
pub fn profiler_loop(
    reader: RingBufReader<FramePayload, RING_BUF_SIZE>,
    sig: libc::c_int,
    target_thread: ThreadId,
    interval: Duration,
    signal_state_addr: usize,
    stop: Arc<AtomicBool>,
    mut process_func: ResolvedBacktraceProcessFunc,
) {
    let signal_state = signal_state_addr as *mut SignalState;
    let sentinel: *mut SignalState = std::ptr::null_mut();

    let mut frames = Vec::new();
    let mut current_backtrace_id: usize = 0;
    let mut expected_depth: isize = 0;

    crate::osutil::block_signal(sig);

    let mut next_signal_time = Instant::now() + interval;

    loop {
        let now = Instant::now();
        if let Some(remaining) = next_signal_time.checked_duration_since(now) {
            thread::park_timeout(remaining);
        }

        let stopping = stop.load(Ordering::Acquire);

        // Drain ring buffer — resolve the previous sample's backtrace.
        while let Some(payload) = reader.pop() {
            process_frame(
                payload,
                &mut frames,
                &mut current_backtrace_id,
                &mut expected_depth,
                &mut process_func,
            );
        }

        if stopping {
            break;
        }

        next_signal_time = Instant::now() + interval;

        // Try to hand our state to the signal handler. On failure
        // (handler still processing the previous sample) just skip.
        if SIGNAL_PAYLOAD
            .compare_exchange(sentinel, signal_state, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
        {
            crate::osutil::signal_thread(target_thread, sig);
        }
    }

    // Clean up if the signal handler hasn't consumed our payload.
    let _ = SIGNAL_PAYLOAD.compare_exchange(
        signal_state,
        sentinel,
        Ordering::AcqRel,
        Ordering::Relaxed,
    );
}

fn process_frame(
    frame: FramePayload,
    frames: &mut Vec<String>,
    current_backtrace_id: &mut usize,
    expected_depth: &mut isize,
    process_func: &mut ResolvedBacktraceProcessFunc,
) {
    if frame.backtrace_id != *current_backtrace_id {
        // A different backtrace (implies a missing EndOfBacktrace).
        frames.clear();
        *current_backtrace_id = frame.backtrace_id;
        *expected_depth = 0;
    }
    if frame.depth as isize != *expected_depth {
        // Out of sync — ignore the rest of this backtrace.
        frames.clear();
        *expected_depth = -1;
        return;
    }
    *expected_depth += 1;
    match frame.frame {
        MaybeFrame::Present(f) => {
            frames.push(f.resolve());
        }
        MaybeFrame::EndOfBacktrace => {
            if !frames.is_empty() {
                process_func(frames);
            }
            frames.clear();
            *expected_depth = 0;
        }
    }
}
