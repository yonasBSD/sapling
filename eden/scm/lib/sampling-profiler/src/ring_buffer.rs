/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Lock-free SPSC ring buffer safe for use in async-signal contexts.
//!
//! The producer side uses only atomic loads/stores and `ptr::write` —
//! no locks, no allocations, no syscalls.

use std::cell::UnsafeCell;
use std::marker::PhantomData;
use std::mem::MaybeUninit;
use std::ptr;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::AtomicUsize;
use std::sync::atomic::Ordering;

/// Create a writer/reader pair sharing a ring buffer of capacity `N`.
///
/// `N` must be a power of two (avoids slow `%` in hot path).
pub fn ring_buffer<T: Copy + Send, const N: usize>() -> (RingBufWriter<T, N>, RingBufReader<T, N>) {
    let shared = Shared::<T, N>::new_arc();
    (
        RingBufWriter {
            shared: shared.clone(),
            _no_sync: PhantomData,
        },
        RingBufReader {
            shared,
            _no_sync: PhantomData,
        },
    )
}

/// Producer handle. `Send` but `!Sync` — can live on one thread only.
pub struct RingBufWriter<T: Copy + Send, const N: usize> {
    shared: Arc<Shared<T, N>>,
    // UnsafeCell is Send + !Sync, giving us Send + !Sync automatically.
    _no_sync: PhantomData<UnsafeCell<()>>,
}

/// Consumer handle. `Send` but `!Sync` — can live on one thread only.
pub struct RingBufReader<T: Copy + Send, const N: usize> {
    shared: Arc<Shared<T, N>>,
    _no_sync: PhantomData<UnsafeCell<()>>,
}

impl<T: Copy + Send, const N: usize> RingBufWriter<T, N> {
    /// Push an item. Returns `true` on success, `false` if full or closed.
    ///
    /// Async-signal-safe: only atomic loads/stores and `ptr::write`.
    pub fn push(&self, value: T) -> bool {
        self.shared.push(value)
    }

    /// Signal that no more items will be produced.
    pub fn close(&self) {
        self.shared.closed.store(true, Ordering::Release);
    }
}

impl<T: Copy + Send, const N: usize> RingBufReader<T, N> {
    /// Pop an item. Returns `None` if empty.
    pub fn pop(&self) -> Option<T> {
        self.shared.pop()
    }

    /// `true` once closed by the writer AND fully drained.
    pub fn is_exhausted(&self) -> bool {
        self.shared.closed.load(Ordering::Acquire) && {
            let tail = self.shared.tail.load(Ordering::Relaxed);
            let head = self.shared.head.load(Ordering::Acquire);
            tail == head
        }
    }
}

// ---------------------------------------------------------------------------
// Shared backing store — not public.
// ---------------------------------------------------------------------------

struct Shared<T, const N: usize> {
    head: AtomicUsize,
    tail: AtomicUsize,
    closed: AtomicBool,
    slots: [UnsafeCell<MaybeUninit<T>>; N],
}

// SPSC invariant is enforced by the Writer/Reader split above.
unsafe impl<T: Send, const N: usize> Send for Shared<T, N> {}
unsafe impl<T: Send, const N: usize> Sync for Shared<T, N> {}

impl<T: Copy, const N: usize> Shared<T, N> {
    const MASK: usize = N - 1;

    /// Allocate directly on the heap — avoids putting the (potentially huge)
    /// slots array on the stack.
    fn new_arc() -> Arc<Self> {
        assert!(N > 0 && N & (N - 1) == 0, "N must be a power of two");
        let mut arc = Arc::new_uninit();
        let p: *mut Self = Arc::get_mut(&mut arc).unwrap().as_mut_ptr();
        unsafe {
            ptr::addr_of_mut!((*p).head).write(AtomicUsize::new(0));
            ptr::addr_of_mut!((*p).tail).write(AtomicUsize::new(0));
            ptr::addr_of_mut!((*p).closed).write(AtomicBool::new(false));
            // MaybeUninit slots require no initialization.
            arc.assume_init()
        }
    }

    fn push(&self, value: T) -> bool {
        if self.closed.load(Ordering::Acquire) {
            return false;
        }
        let head = self.head.load(Ordering::Relaxed);
        let tail = self.tail.load(Ordering::Acquire);
        if head.wrapping_sub(tail) >= N {
            return false;
        }
        unsafe {
            let slot = self.slots.get_unchecked(head & Self::MASK).get();
            slot.write(MaybeUninit::new(value));
        }
        self.head.store(head.wrapping_add(1), Ordering::Release);
        true
    }

    fn pop(&self) -> Option<T> {
        let tail = self.tail.load(Ordering::Relaxed);
        let head = self.head.load(Ordering::Acquire);
        if tail == head {
            return None;
        }
        let value = unsafe {
            let slot = self.slots.get_unchecked(tail & Self::MASK).get();
            (*slot).assume_init()
        };
        self.tail.store(tail.wrapping_add(1), Ordering::Release);
        Some(value)
    }
}

#[cfg(test)]
mod tests {
    use std::thread;

    use super::*;

    #[test]
    fn push_pop_basic() {
        let (w, r) = ring_buffer::<u64, 4>();
        assert!(r.pop().is_none());

        assert!(w.push(10));
        assert!(w.push(20));
        assert_eq!(r.pop(), Some(10));
        assert_eq!(r.pop(), Some(20));
        assert!(r.pop().is_none());
    }

    #[test]
    fn full_buffer_rejects() {
        let (w, r) = ring_buffer::<u32, 2>();
        assert!(w.push(1));
        assert!(w.push(2));
        assert!(!w.push(3));

        assert_eq!(r.pop(), Some(1));
        assert!(w.push(3));
        assert_eq!(r.pop(), Some(2));
        assert_eq!(r.pop(), Some(3));
    }

    #[test]
    fn wraparound() {
        let (w, r) = ring_buffer::<u32, 4>();
        for round in 0..10 {
            for i in 0..4 {
                assert!(w.push(round * 4 + i));
            }
            assert!(!w.push(99));
            for i in 0..4 {
                assert_eq!(r.pop(), Some(round * 4 + i));
            }
        }
    }

    #[test]
    fn close_rejects_push() {
        let (w, r) = ring_buffer::<u32, 4>();
        assert!(w.push(1));
        w.close();
        assert!(!w.push(2));

        assert_eq!(r.pop(), Some(1));
        assert!(r.pop().is_none());
        assert!(r.is_exhausted());
    }

    #[test]
    fn close_and_drain() {
        let (w, r) = ring_buffer::<u32, 4>();
        w.push(1);
        w.push(2);
        w.close();

        assert!(!r.is_exhausted());
        assert_eq!(r.pop(), Some(1));
        assert!(!r.is_exhausted());
        assert_eq!(r.pop(), Some(2));
        assert!(r.is_exhausted());
    }

    #[test]
    fn large_buffer_on_heap() {
        // 16 MB — would blow any normal stack.
        // Run on a thread with a small stack to prove it's heap-allocated.
        thread::Builder::new()
            .stack_size(1024 * 1024)
            .spawn(|| {
                let (w, r) = ring_buffer::<[u8; 4096], 4096>();
                assert!(w.push([42; 4096]));
                assert_eq!(r.pop().unwrap()[0], 42);
            })
            .unwrap()
            .join()
            .unwrap();
    }

    #[test]
    fn spsc_concurrent() {
        const COUNT: usize = 1_000_000;
        let (w, r) = ring_buffer::<usize, 1024>();

        let producer = thread::spawn(move || {
            for i in 0..COUNT {
                while !w.push(i) {
                    thread::yield_now();
                }
            }
            w.close();
        });

        let mut next = 0;
        loop {
            match r.pop() {
                Some(v) => {
                    assert_eq!(v, next);
                    next += 1;
                }
                None if r.is_exhausted() => break,
                None => thread::yield_now(),
            }
        }
        assert_eq!(next, COUNT);
        producer.join().unwrap();
    }
}
