/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::sync::atomic::AtomicUsize;
use std::sync::atomic::Ordering;

use backtrace_ext::trace_unsynchronized;

use crate::frame_handler::FramePayload;
use crate::frame_handler::MaybeFrame;
use crate::frame_handler::RING_BUF_SIZE;
use crate::ring_buffer::RingBufWriter;

/// State shared between the profiler and the signal handler.
/// Must remain at a stable address (the signal handler receives a raw pointer).
pub struct SignalState {
    pub writer: RingBufWriter<FramePayload, RING_BUF_SIZE>,
}

/// Signal handler: capture a backtrace and push frames to the ring buffer.
///
/// Uses only async-signal-safe operations (atomic loads/stores, ptr::write).
/// No syscalls, no allocations, no errno clobbering.
pub extern "C" fn signal_handler(
    sig: libc::c_int,
    _info: *const libc::siginfo_t,
    _data: *const libc::c_void,
) {
    if sig != libc::SIGPROF {
        return;
    }

    let state_ptr = crate::osutil::SIGNAL_PAYLOAD.swap(std::ptr::null_mut(), Ordering::AcqRel);
    if state_ptr.is_null() {
        return;
    }
    let writer = unsafe { &(*state_ptr).writer };

    let backtrace_id: usize = {
        static BACKTRACE_ID: AtomicUsize = AtomicUsize::new(0);
        BACKTRACE_ID.fetch_add(1, Ordering::AcqRel)
    };
    let mut depth = 0;

    // Skip the first frames.
    const SKIP_FRAMES: usize = if cfg!(target_os = "linux") {
        // - signal_handler (this function)
        // - __sigaction
        2
    } else if cfg!(target_os = "macos") {
        // - backtrace::trace_unsynchronized
        // - signal_handler (this function)
        // - __sigtramp
        3
    } else {
        // Guess
        2
    };
    trace_unsynchronized!(|frame| {
        if depth >= SKIP_FRAMES {
            let payload = FramePayload {
                backtrace_id,
                depth: depth.saturating_sub(SKIP_FRAMES),
                frame: MaybeFrame::Present(frame),
            };
            if !writer.push(payload) {
                // Poison depth so this incomplete backtrace gets dropped.
                depth += 2;
                return false;
            }
        }
        depth += 1;
        true
    });

    // Mark end of backtrace.
    let payload = FramePayload {
        backtrace_id,
        depth: depth.saturating_sub(SKIP_FRAMES),
        frame: MaybeFrame::EndOfBacktrace,
    };
    let _ = writer.push(payload);
}
