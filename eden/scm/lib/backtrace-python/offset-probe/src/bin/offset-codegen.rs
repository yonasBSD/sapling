/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Binary to probe for offsets and output Rust constants.
//! Writes a Rust source file with OFFSET_IP and OFFSET_SP constants.

use std::io;
use std::io::Write;

fn main() {
    let code = backtrace_python_offset_probe::get_offsets_code();
    let mut out = io::stdout();
    out.write_all(code.as_bytes()).unwrap();
    out.flush().unwrap();
}
