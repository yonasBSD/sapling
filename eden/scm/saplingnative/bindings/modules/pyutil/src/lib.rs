/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#![allow(non_camel_case_types)]

use cpython::*;
use cpython_ext::ResultPyErrExt;

pub fn init_module(py: Python, package: &str) -> PyResult<PyModule> {
    let name = [package, "util"].join(".");
    let m = PyModule::new(py, &name)?;
    m.add(
        py,
        "is_plain",
        py_fn!(py, is_plain(feature: Option<String> = None)),
    )?;
    m.add(py, "username", py_fn!(py, username()))?;
    Ok(m)
}

fn is_plain(_py: Python, feature: Option<String>) -> PyResult<bool> {
    Ok(hgplain::is_plain(feature.as_deref()))
}

fn username(py: Python) -> PyResult<String> {
    sysutil::username().map_pyerr(py)
}
