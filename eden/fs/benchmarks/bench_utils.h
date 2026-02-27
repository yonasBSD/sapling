/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <folly/io/async/AsyncSocket.h>
#include <thrift/lib/cpp2/async/HeaderClientChannel.h>
#include "eden/common/utils/PathFuncs.h"
#include "eden/fs/service/gen-cpp2/EdenService.h"

#ifdef _WIN32
#include <filesystem>
#include <fstream>
#endif

namespace facebook::eden::benchmarks {

#ifdef _WIN32
inline std::optional<AbsolutePath> getSocketPathFromConfig(
    const AbsolutePath& mountPath) {
  auto configPath = mountPath + ".eden/config"_relpath;

  if (!std::filesystem::exists(configPath.asString())) {
    return std::nullopt;
  }

  std::ifstream configFile(configPath.asString());
  if (!configFile.is_open()) {
    return std::nullopt;
  }

  std::string line;
  while (std::getline(configFile, line)) {
    line.erase(0, line.find_first_not_of(" \t\r\n"));
    line.erase(line.find_last_not_of(" \t\r\n") + 1);

    if (line.find("socket = ") == 0) {
      std::string socketPart = line.substr(9);

      if (!socketPart.empty() &&
          ((socketPart.front() == '"' && socketPart.back() == '"') ||
           (socketPart.front() == '\'' && socketPart.back() == '\''))) {
        socketPart = socketPart.substr(1, socketPart.length() - 2);
      }

      try {
        return canonicalPath(socketPart);
      } catch (const std::exception&) {
        return std::nullopt;
      }
    }
  }

  return std::nullopt;
}
#endif

/**
 * Get the EdenFS thrift socket path for a given mount point.
 *
 * On Unix, the socket is a symlink at <mount>/.eden/socket.
 * On Windows, the socket path is parsed from <mount>/.eden/config.
 *
 * @param mountPath Absolute path to the EdenFS mount point
 * @return Absolute path to the EdenFS thrift socket
 */
inline AbsolutePath getEdenSocketPath(const AbsolutePath& mountPath) {
#ifdef _WIN32
  auto socketPath = getSocketPathFromConfig(mountPath);
  if (socketPath) {
    return *socketPath;
  }
  throw std::runtime_error(
      "Could not find socket path in .eden/config file for Windows mount: " +
      mountPath.asString());
#else
  return mountPath + ".eden/socket"_relpath;
#endif
}

/**
 * Create a thrift client connected to the EdenFS daemon.
 *
 * @param eventBase Event base for async I/O
 * @param socketPath Absolute path to the EdenFS thrift socket
 * @return Connected apache::thrift::Client<EdenService>
 */
inline std::unique_ptr<apache::thrift::Client<EdenService>>
createEdenThriftClient(
    folly::EventBase* eventBase,
    const AbsolutePath& socketPath) {
  auto socket = folly::AsyncSocket::newSocket(
      eventBase, folly::SocketAddress::makeFromPath(socketPath.view()));
  auto channel =
      apache::thrift::HeaderClientChannel::newChannel(std::move(socket));
  return std::make_unique<apache::thrift::Client<EdenService>>(
      std::move(channel));
}

} // namespace facebook::eden::benchmarks
