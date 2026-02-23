/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::fs;
use std::io;
use std::io::Read as _;
use std::os::fd::AsRawFd;
use std::os::fd::FromRawFd;
use std::sync::atomic::Ordering;
use std::time::Duration;

use backtrace_ext::Frame;

use crate::ResolvedBacktraceProcessFunc;
use crate::osutil::OwnedFd;
use crate::osutil::SIGNAL_PAYLOAD;
use crate::osutil::ThreadId;
use crate::signal_handler::SignalState;

/// `Frame` payload being written to pipes.
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

enum PollResult {
    DataReady,
    Timeout,
    Closed,
}

/// Combined frame-reader + timer loop. Uses `poll()` timeout as the sampling
/// timer, eliminating the need for a separate timer thread.
///
/// - On data ready: reads and processes frames from the pipe.
/// - On timeout: CAS the signal payload and signal the target thread.
/// - On hangup: drains remaining frames and exits.
pub fn profiler_loop(
    read_fd: OwnedFd,
    sig: libc::c_int,
    target_thread: ThreadId,
    interval: Duration,
    signal_state_addr: usize,
    mut process_func: ResolvedBacktraceProcessFunc,
) {
    let mut read_file = match read_fd.into_raw_fd() {
        Some(fd) => unsafe { fs::File::from_raw_fd(fd) },
        None => return,
    };

    let interval_ms = interval.as_millis().max(1) as libc::c_int;
    let signal_state = signal_state_addr as *mut SignalState;
    let sentinel: *mut SignalState = std::ptr::null_mut();

    let mut frames = Vec::new();
    let mut current_backtrace_id = 0;
    let mut expected_depth = 0;

    crate::osutil::block_signal(sig);

    loop {
        match poll_with_timeout(read_file.as_raw_fd(), interval_ms) {
            PollResult::DataReady => {}
            PollResult::Timeout => {
                // Try to hand our state to the signal handler. On failure
                // (handler still processing the previous sample) just skip.
                if SIGNAL_PAYLOAD
                    .compare_exchange(sentinel, signal_state, Ordering::AcqRel, Ordering::Acquire)
                    .is_ok()
                {
                    crate::osutil::signal_thread(target_thread, sig);
                }
                continue;
            }
            PollResult::Closed => break,
        }

        const SIZE: usize = std::mem::size_of::<FramePayload>();
        let mut buf: [u8; SIZE] = [0; _];
        match read_file.read_exact(&mut buf) {
            Ok(()) => {}
            Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => {
                // The pipe was closed. `read_file` will be closed on drop.
                break;
            }
            Err(_) => {
                // Incomplete packet? Ignore.
                continue;
            }
        }
        // safety: FramePayload is `repr(C)` and contains only `usize` fields.
        // It is okay to use `transmute` to "deserialize" within the same process.
        let frame: FramePayload = unsafe { std::mem::transmute(buf) };
        if frame.backtrace_id != current_backtrace_id {
            // A different backtrace (implies a missing EndOfBacktrace).
            frames.clear();
            current_backtrace_id = frame.backtrace_id;
            expected_depth = 0;
        }
        if frame.depth as isize != expected_depth {
            // This backtrace is bad (out of sync).
            // Ignore the rest of the frames of the same backtrace.
            frames.clear();
            expected_depth = -1;
            continue;
        } else {
            expected_depth += 1;
        }
        match frame.frame {
            MaybeFrame::Present(frame) => {
                let name = frame.resolve();
                frames.push(name);
            }
            MaybeFrame::EndOfBacktrace => {
                // The end of a backtrace.
                if !frames.is_empty() {
                    process_func(&frames);
                }
                frames.clear();
                expected_depth = 0;
            }
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

/// Poll `fd` with a timeout in milliseconds.
/// Returns `DataReady` when data is available, `Timeout` on expiry,
/// or `Closed` on hangup-with-no-data / error.
fn poll_with_timeout(fd: libc::c_int, timeout_ms: libc::c_int) -> PollResult {
    let mut pollfd = libc::pollfd {
        fd,
        events: libc::POLLIN,
        revents: 0,
    };
    loop {
        let ret = unsafe { libc::poll(&mut pollfd, 1, timeout_ms) };
        if ret > 0 {
            if pollfd.revents & libc::POLLIN != 0 {
                return PollResult::DataReady;
            }
            // POLLHUP without POLLIN — pipe closed, no more data.
            return PollResult::Closed;
        }
        if ret == 0 {
            return PollResult::Timeout;
        }
        // ret < 0: error
        if io::Error::last_os_error().raw_os_error() == Some(libc::EINTR) {
            continue;
        }
        return PollResult::Closed;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(target_os = "linux")]
    #[test]
    fn test_frame_size() {
        // See `man pipe2`. We use `O_DIRECT` for "packet-mode" pipes.
        // The packet has size limit: `PIPE_BUF`. The payload (MaybeFrame)
        // must fit in.
        assert!(std::mem::size_of::<FramePayload>() <= libc::PIPE_BUF);
    }
}
