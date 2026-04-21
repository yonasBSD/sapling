/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <string_view>

/*
 * Key constants for XplatLogger's DynamicEvent key-value bags.
 *
 * XplatLogger logs to arbitrary Scuba tables via a generic
 * logEvent(category, DynamicEvent) method. A DynamicEvent is a bag of
 * key-value pairs carrying event-specific fields — fields that differ
 * across tables. (Shared identity fields like username, hostname, and
 * session_id are populated automatically by the transform layer from
 * EdenTelemetryIdentity.)
 *
 * These constants are shared between call sites (which populate the
 * DynamicEvent) and transform functions (which extract values to build
 * typed Thrift structs). Centralising them here prevents typos and
 * keeps key names in one place. Key names match Scuba column names
 * exactly for debuggability.
 *
 * When adding a new table, add its event-specific key constants here.
 */
namespace facebook::eden::xplat_keys {

// --- edenfs_file_accesses fields ---
inline constexpr std::string_view kRepo = "repo";
inline constexpr std::string_view kDirectory = "directory";
inline constexpr std::string_view kFilename = "filename";
inline constexpr std::string_view kSource = "source";
inline constexpr std::string_view kSourceDetail = "source_detail";
inline constexpr std::string_view kWeight = "weight";

} // namespace facebook::eden::xplat_keys
