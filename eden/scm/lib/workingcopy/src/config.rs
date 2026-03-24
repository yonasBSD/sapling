/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Tweakable configs for working copy.

use std::sync::LazyLock;
use std::sync::atomic::AtomicBool;

/// Whether to use `--no-optional-locks` for `git status` calls.
///
/// - Using this flag, git can become very slow over time,
///   e.g. https://github.com/facebook/sapling/issues/929
/// - Not using this flag, frequent command calls (e.g. by some problematic
///   automation) can starve legit user commands in terminal (e.g. checkout).
///   If the frequency is too high, the user commands can have >50% chances
///   to fail. https://fburl.com/workplace/avjspdkk
///
/// The proper fix would be to change git upstream to wait for the index lock
/// instead of immediately failing.
pub static DOTGIT_NO_OPTIONAL_LOCKS: LazyLock<AtomicBool> = LazyLock::new(|| {
    let is_automation = hgplain::is_plain(Some("dotgit-no-optional-locks"));
    AtomicBool::new(is_automation)
});
