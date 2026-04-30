/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#![allow(unexpected_cfgs)]

//! `backtrace-ext` extension to support resolving Python frames.
//!
//! Call `init()` after Python initialization to attempt to enable Python frame
//! resolution. Not all platforms are supported. Check `SUPPORTED_INFO` for
//! whether it's supported or not.

use std::ffi::CStr;
use std::sync::LazyLock;

use backtrace_ext::FrameDecision;
use backtrace_ext::SupplementalFrameResolver;
use backtrace_ext::SupplementalInfo;

mod libpython_filter;

#[cfg(offsets_codegen_by_cargo)]
pub mod offsets {
    include!(concat!(env!("OUT_DIR"), "/offsets.rs"));
}

#[cfg(not(offsets_codegen_by_cargo))]
pub mod offsets;

/// Setup backtrace-ext to resolve Python frames on supported platforms.
/// This function is a no-op if the platform is not supported.
///
/// Calling this function when the Python interpreter is not initialized does
/// not complete the initialization. Call again after Python initialization.
pub fn init() {
    let is_supported = SUPPORTED_INFO.is_supported();
    if is_supported {
        static RESOLVER: PythonSupplementalFrameResolver = PythonSupplementalFrameResolver;
        static RESOLVER_FAT_REF: &dyn SupplementalFrameResolver = &RESOLVER;
        static RESOLVER_THIN_REF: &&dyn SupplementalFrameResolver = &RESOLVER_FAT_REF;
        libpython_filter::init();
        backtrace_ext::set_supplemental_frame_resolver(Some(RESOLVER_THIN_REF));
        unsafe {
            // This function is a no-op if called before Python initialization.
            evalframe_sys::set_mode(evalframe_sys::EvalFrameMode::Enabled);
            // keep the C function alive (for dbgutil.py lldb usage)
            evalframe_sys::resolve_frame(0);
        }
    }
}

/// Information about whether the Python frame resolution is supported or not.
/// All fields must be `true` to indicate support.
#[derive(Clone, Copy, Debug)]
pub struct SupportedInfo {
    /// Whether the (OS, architecture) combination is supported.
    /// Decided by whether the `offsets` can be detected at build time.
    pub os_arch: bool,
    /// Whether the C evalframe logic supports frame resolution.
    /// This is usually affected by the cpython version.
    pub c_evalframe: bool,
}

impl SupportedInfo {
    pub fn is_supported(&self) -> bool {
        self.os_arch && self.c_evalframe
    }

    fn new() -> Self {
        Self {
            os_arch: offsets::OFFSET_IP.is_some()
                && offsets::OFFSET_SP_CODE.is_some()
                && offsets::OFFSET_SP_LINE_NO.is_some(),
            c_evalframe: evalframe_sys::resolve_frame_is_supported(),
        }
    }
}

pub static SUPPORTED_INFO: LazyLock<SupportedInfo> = LazyLock::new(SupportedInfo::new);

#[derive(Copy, Clone)]
struct PythonSupplementalFrameResolver;

impl SupplementalFrameResolver for PythonSupplementalFrameResolver {
    fn maybe_extract_supplemental_info(&self, ip: usize, sp: usize) -> FrameDecision {
        let start = evalframe_sys::sapling_py_eval_frame_addr();
        let Some(offset_ip) = offsets::OFFSET_IP else {
            // Offsets not provided (e.g. unsupported arch or python)
            return FrameDecision::Keep;
        };
        if ip != start + offset_ip {
            // Skip native python frames to reduce noise.
            return if libpython_filter::is_python_frame(ip) {
                FrameDecision::Skip
            } else {
                // Skip other places of Sapling_PyEvalFrameInner native frame
                if ip >= start && ip <= start + offset_ip {
                    return FrameDecision::Skip;
                }
                FrameDecision::Keep
            };
        }

        // Read stack of Sapling_PyEvalFrameInner
        match extract_python_supplemental_info(sp) {
            Some(info) => FrameDecision::Replace(info),
            None => FrameDecision::Keep,
        }
    }

    fn resolve_supplemental_info(&self, info: &SupplementalInfo) -> Option<String> {
        let [code, line_no] = *info;
        unsafe {
            let mut filename_ptr: *const libc::c_char = std::ptr::null();
            let name_ptr =
                evalframe_sys::resolve_code_object(code as *mut libc::c_void, &mut filename_ptr);
            if !name_ptr.is_null() && !filename_ptr.is_null() {
                let name_cstr = CStr::from_ptr(name_ptr);
                let filename_cstr = CStr::from_ptr(filename_ptr);
                let desc = format!(
                    "{} at {}:{}",
                    name_cstr.to_string_lossy(),
                    filename_cstr.to_string_lossy(),
                    line_no
                );
                return Some(desc);
            }
        }
        None
    }
}

fn extract_python_supplemental_info(sp: usize) -> Option<SupplementalInfo> {
    if sp == 0 {
        return None;
    }

    let read_stack = |offset: usize| -> Option<usize> {
        let addr = sp.checked_add(offset)?;
        unsafe {
            let stack_ptr: *const *mut libc::c_void = addr as *const _;
            Some(*stack_ptr as usize)
        }
    };

    let code_obj = read_stack(offsets::OFFSET_SP_CODE?)?;
    let line_no = read_stack(offsets::OFFSET_SP_LINE_NO?)?;

    Some([code_obj, line_no])
}
