/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <memory>

#include "eden/fs/telemetry/EdenStructuredLogger.h"

namespace facebook::eden {

class ReloadableConfig;
class ScribeLogger;
struct DaemonError;

/**
 * StructuredLogger subclass for error telemetry. Provides a
 * logEvent(DaemonError) overload that checks enableErrorLogging
 * config and uploads stack traces to Manifold before logging.
 */
class ErrorLogger : public EdenStructuredLogger {
 public:
  ErrorLogger(
      std::shared_ptr<ScribeLogger> scribeLogger,
      SessionInfo sessionInfo,
      std::shared_ptr<ReloadableConfig> config);

  ~ErrorLogger() override = default;

  /**
   * Check config, upload stack trace to Manifold if enabled,
   * and log a DaemonError event. No-op when enableErrorLogging
   * is false.
   */
  void logEvent(DaemonError event);

 private:
  std::shared_ptr<ReloadableConfig> config_;
};

} // namespace facebook::eden
