/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Operation system features used by the profiler.

use std::io;
use std::mem;
use std::sync::atomic::AtomicPtr;

use anyhow::Context;

use crate::signal_handler::SignalState;

/// Atomic payload for passing data from the profiler thread to the signal handler.
/// The profiler thread CAS's from null to the pointer, sends the signal, and the
/// signal handler reads and resets it to null.
pub static SIGNAL_PAYLOAD: AtomicPtr<SignalState> = AtomicPtr::new(std::ptr::null_mut());

// Block `sig` signals. Explicitly opt-out profiling for the current thread
// and new threads spawned from the current thread.
pub fn block_signal(sig: libc::c_int) {
    sigmask_sigprof(sig, true);
}

/// Unblock `sig` to enable profiling.
pub fn unblock_signal(sig: libc::c_int) {
    sigmask_sigprof(sig, false);
}

/// Thread identifier type: Linux uses kernel tid, others use pthread_t.
#[cfg(target_os = "linux")]
pub type ThreadId = libc::pid_t;

#[cfg(all(unix, not(target_os = "linux")))]
pub type ThreadId = libc::pthread_t;

// Get the current thread id. Must be async-signal-safe.
#[cfg(target_os = "linux")]
pub fn get_thread_id() -> ThreadId {
    unsafe { libc::syscall(libc::SYS_gettid) as ThreadId }
}

#[cfg(all(unix, not(target_os = "linux")))]
pub fn get_thread_id() -> ThreadId {
    unsafe { libc::pthread_self() }
}

/// Send signal `sig` to the thread identified by `tid`.
#[cfg(target_os = "linux")]
pub fn signal_thread(tid: ThreadId, sig: libc::c_int) {
    // tgkill targets a specific thread within our process.
    unsafe {
        libc::syscall(libc::SYS_tgkill, libc::getpid(), tid, sig);
    }
}

#[cfg(all(unix, not(target_os = "linux")))]
pub fn signal_thread(tid: ThreadId, sig: libc::c_int) {
    unsafe {
        libc::pthread_kill(tid, sig);
    }
}

/// Similar to stdlib `OwnedFd`.
/// But also allows a "null" state, and supports `close` early.
pub struct OwnedFd(pub i32);

impl OwnedFd {
    pub fn close(&mut self) {
        if self.0 >= 0 {
            let _ = unsafe { libc::close(self.0) };
            self.0 = -1;
        }
    }

    pub fn into_raw_fd(mut self) -> Option<i32> {
        let mut ret = None;
        if self.0 >= 0 {
            ret = Some(self.0);
            self.0 = -1;
        }
        ret
    }
}

impl Drop for OwnedFd {
    fn drop(&mut self) {
        self.close();
    }
}

/// Create a pipe for SIGPROF signal handler use.
/// The SIGPROF handler sends raw stack trace info to the pipe.
/// The other end of the pipe consumes the data and might resolve symbols.
///
/// The pipe is non-blocking on both ends. The signal handler gracefully drops
/// frames when the buffer is full (EAGAIN). The reader uses poll() to wait.
///
/// On Linux the pipe is additionally configured with:
/// - O_DIRECT: Enables "packet-mode". No need to deal with payload boundaries.
/// - A larger buffer to reduce chances data gets dropped.
///
/// Returns `[read_fd, write_fd]`.
pub fn setup_pipe() -> anyhow::Result<[OwnedFd; 2]> {
    #[cfg(target_os = "linux")]
    unsafe {
        let mut pipe_fds: [libc::c_int; 2] = [0; 2];

        if libc::pipe2(pipe_fds.as_mut_ptr(), libc::O_DIRECT | libc::O_NONBLOCK) != 0 {
            return Err(io::Error::last_os_error()).context("pipe2(O_DIRECT | O_NONBLOCK)");
        }
        let (rfd, wfd) = (OwnedFd(pipe_fds[0]), OwnedFd(pipe_fds[1]));

        // The default pipe buffer is 4KB. It fits ~100 frames. Try to use a larger
        // buffer so the signal handler is less likely blocking.
        // Linux has a per-user pipe pages limit /proc/sys/fs/pipe-user-pages-soft
        // (and -hard). Try to not use too much. 16x the original size gives us
        // ~1.6k frames.
        // If this fails, that's okay too. It's just an optimization.
        let buffer_size = 65536;
        let _ret = libc::fcntl(pipe_fds[1], libc::F_SETPIPE_SZ, buffer_size);

        Ok([rfd, wfd])
    }

    #[cfg(all(unix, not(target_os = "linux")))]
    unsafe {
        let mut pipe_fds: [libc::c_int; 2] = [0; 2];
        if libc::pipe(pipe_fds.as_mut_ptr()) != 0 {
            return Err(io::Error::last_os_error()).context("pipe");
        }
        let (rfd, wfd) = (OwnedFd(pipe_fds[0]), OwnedFd(pipe_fds[1]));

        for &fd in &pipe_fds {
            if libc::fcntl(fd, libc::F_SETFL, libc::O_NONBLOCK) != 0 {
                let err = io::Error::last_os_error();
                return Err(err).context("fcntl(F_SETFL, O_NONBLOCK)");
            }
        }
        Ok([rfd, wfd])
    }

    #[cfg(not(unix))]
    anyhow::bail!("unsupported platform")
}

/// Setup the signal handler. This is POSIX-only.
pub fn setup_signal_handler(
    sig: libc::c_int,
    signal_handler: extern "C" fn(libc::c_int, *const libc::siginfo_t, *const libc::c_void),
) -> anyhow::Result<()> {
    unsafe {
        let mut sa: libc::sigaction = std::mem::zeroed();
        sa.sa_sigaction = signal_handler as usize;
        sa.sa_flags = libc::SA_RESTART | libc::SA_SIGINFO;
        libc::sigemptyset(&mut sa.sa_mask);
        libc::sigaddset(&mut sa.sa_mask, sig); // Prevents re-entrancy
        if libc::sigaction(sig, &sa, std::ptr::null_mut()) != 0 {
            return Err(io::Error::last_os_error()).context("sigaction");
        }
    }

    Ok(())
}

/// Consume all pending instances of `sig` for the current thread.
/// The signal must be blocked before calling this function (see `block_signal`),
/// otherwise signals may be delivered to the handler instead of being drained.
pub fn drain_pending_signals(sig: libc::c_int) {
    unsafe {
        let mut set: libc::sigset_t = mem::zeroed();
        libc::sigemptyset(&mut set);
        libc::sigaddset(&mut set, sig);

        let mut pending: libc::sigset_t = mem::zeroed();
        while libc::sigpending(&mut pending) == 0 && libc::sigismember(&pending, sig) == 1 {
            let mut caught: libc::c_int = 0;
            libc::sigwait(&set, &mut caught);
        }
    }
}

fn sigmask_sigprof(sig: libc::c_int, block: bool) {
    unsafe {
        let mut set: libc::sigset_t = mem::zeroed();
        libc::sigemptyset(&mut set);
        libc::sigaddset(&mut set, sig);
        let how = match block {
            true => libc::SIG_BLOCK,
            _ => libc::SIG_UNBLOCK,
        };
        libc::pthread_sigmask(how, &set, std::ptr::null_mut());
    }
}
