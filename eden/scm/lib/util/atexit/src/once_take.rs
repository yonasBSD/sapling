/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::cell::UnsafeCell;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;

/// Stores a value that can be "taken" once, mut-free, lock-free.
pub struct OnceTake<T> {
    taken: AtomicBool,
    value: UnsafeCell<Option<T>>,
}

// Safety: The AtomicBool swap ensures at most one thread accesses
// the UnsafeCell, so shared access (&OnceTake) is safe when T: Send.
// T: Send (not Sync) suffices because the value is moved out, never
// shared by reference.
unsafe impl<T: Send> Sync for OnceTake<T> {}
unsafe impl<T: Send> Send for OnceTake<T> {}

impl<T> OnceTake<T> {
    pub const fn new(v: T) -> Self {
        Self {
            taken: AtomicBool::new(false),
            value: UnsafeCell::new(Some(v)),
        }
    }
    pub fn take(&self) -> Option<T> {
        if !self.taken.swap(true, Ordering::AcqRel) {
            // Safety: The atomic swap above ensures exactly one thread
            // ever enters this branch. No concurrent access to the cell.
            unsafe { (*self.value.get()).take() }
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn take_returns_value_once() {
        let once = OnceTake::new(42);
        assert_eq!(once.take(), Some(42));
        assert_eq!(once.take(), None);
        assert_eq!(once.take(), None);
    }

    #[test]
    fn drop_without_take() {
        use std::sync::Arc;
        use std::sync::atomic::Ordering;

        let dropped = Arc::new(AtomicBool::new(false));
        struct Guard(Arc<AtomicBool>);
        impl Drop for Guard {
            fn drop(&mut self) {
                self.0.store(true, Ordering::Release);
            }
        }

        let once = OnceTake::new(Guard(dropped.clone()));
        drop(once);
        assert!(dropped.load(Ordering::Acquire));
    }

    #[test]
    fn take_then_drop_does_not_double_drop() {
        use std::sync::Arc;
        use std::sync::atomic::AtomicUsize;
        use std::sync::atomic::Ordering;

        let count = Arc::new(AtomicUsize::new(0));
        struct Counter(Arc<AtomicUsize>);
        impl Drop for Counter {
            fn drop(&mut self) {
                self.0.fetch_add(1, Ordering::Release);
            }
        }

        let once = OnceTake::new(Counter(count.clone()));
        let val = once.take();
        assert!(val.is_some());
        drop(val);
        assert_eq!(count.load(Ordering::Acquire), 1);
        drop(once);
        assert_eq!(count.load(Ordering::Acquire), 1);
    }

    #[test]
    fn concurrent_takes() {
        use std::sync::Arc;
        use std::sync::Barrier;
        use std::sync::atomic::AtomicUsize;
        use std::sync::atomic::Ordering;

        let once = Arc::new(OnceTake::new(()));
        let barrier = Arc::new(Barrier::new(8));
        let winners = Arc::new(AtomicUsize::new(0));

        let threads: Vec<_> = (0..8)
            .map(|_| {
                let once = once.clone();
                let barrier = barrier.clone();
                let winners = winners.clone();
                std::thread::spawn(move || {
                    barrier.wait();
                    if once.take().is_some() {
                        winners.fetch_add(1, Ordering::Relaxed);
                    }
                })
            })
            .collect();

        for t in threads {
            t.join().unwrap();
        }

        assert_eq!(winners.load(Ordering::Relaxed), 1);
    }
}
