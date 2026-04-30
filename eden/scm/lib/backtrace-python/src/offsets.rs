/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Offsets for extracting Python frames from native stack traces.
//!
//! This file exists to make static analysis work.
//! Both cargo and buck build will re-generate this file at build time.

/// IP offset within Sapling_PyEvalFrame where the PyFrame can be read.
pub const OFFSET_IP: Option<usize> = None;

/// SP offset to read the PyFrame pointer.
pub const OFFSET_SP: Option<usize> = None;
