/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! Three-way merge for text files.
//!
//! Provides a content-level 3-way merge algorithm matching Git's auto-merge
//! behavior. Given three versions of a file (base, local, other), determines
//! whether the changes from both sides can be combined without conflicts.
//!
//! Uses xdiff (the same diff engine as Git) to compute matching blocks,
//! then applies the classic "sync regions" algorithm to classify and
//! merge the gaps.

pub mod utils;
