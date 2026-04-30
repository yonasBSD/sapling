/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Build script for backtrace-python.
//!
//! This probes the offsets needed to extract Python frames from native stack
//! traces and passes them to the compiler via environment variables.

use std::fs;
use std::path::Path;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    let code = backtrace_python_offset_probe::get_offsets_code();
    let out_dir = std::env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("offsets.rs");
    fs::write(&dest_path, code).unwrap();

    println!("cargo::rustc-check-cfg=cfg(offsets_codegen_by_cargo)");
    println!("cargo::rustc-cfg=offsets_codegen_by_cargo");
}
