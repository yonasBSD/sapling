/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <optional>
#include <string>

namespace facebook::eden {

/**
 * Returns the throw-site stack trace for the current exception.
 * Must be called inside a catch block.
 *
 * Platform-specific implementations:
 *   Linux:   folly::exception_tracer (hooks __cxa_throw via --wrap)
 *   macOS:   Not yet implemented (returns std::nullopt)
 *   Windows: Not yet implemented (returns std::nullopt)
 */
std::optional<std::string> getThrowSiteStackTrace();

} // namespace facebook::eden
