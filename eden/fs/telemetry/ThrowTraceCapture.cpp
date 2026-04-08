/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/telemetry/ThrowTraceCapture.h"

#ifdef __linux__
// =============================================================================
// Linux: folly::exception_tracer
//
// Uses __cxa_throw hook (via --wrap linker flag) to capture stack frames at
// throw time. Frames are stored in thread-local StackTraceStack and symbolized
// via folly's ELF/DWARF symbolizer.
// =============================================================================

#include <sstream>

#include <folly/debugging/exception_tracer/ExceptionTracer.h>

namespace facebook::eden {

std::optional<std::string> getThrowSiteStackTrace() {
  auto exceptions = folly::exception_tracer::getCurrentExceptions();
  if (!exceptions.empty()) {
    std::ostringstream ss;
    for (const auto& info : exceptions) {
      ss << info;
    }
    auto trace = ss.str();
    if (!trace.empty()) {
      return trace;
    }
  }
  return std::nullopt;
}

} // namespace facebook::eden

#else
// =============================================================================
// Unsupported platform — no throw-site stack traces available.
// =============================================================================

namespace facebook::eden {

std::optional<std::string> getThrowSiteStackTrace() {
  return std::nullopt;
}

} // namespace facebook::eden

#endif // __linux__
