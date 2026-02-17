/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

mod receive_pack;
#[cfg(fbcode_build)]
pub(crate) mod rl_land_service_diversion;

pub use receive_pack::receive_pack;
