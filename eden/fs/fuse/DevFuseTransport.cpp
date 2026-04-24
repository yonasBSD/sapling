/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#ifndef _WIN32

#include "eden/fs/fuse/DevFuseTransport.h"

#include <stdexcept>

namespace facebook::eden {

namespace {

[[noreturn]] void throwNotImplemented() {
  throw std::logic_error("DevFuseTransport is not implemented");
}

} // namespace

const char* DevFuseTransport::getName() const {
  // Not implemented yet.
  throwNotImplemented();
}

ssize_t DevFuseTransport::readInitPacket(int, void*, size_t) const {
  // Not implemented yet.
  throwNotImplemented();
}

void DevFuseTransport::processSession(FuseChannel&) {
  // Not implemented yet.
  throwNotImplemented();
}

void DevFuseTransport::replyError(FuseChannel&, const fuse_in_header&, int)
    const {
  // Not implemented yet.
  throwNotImplemented();
}

void DevFuseTransport::sendRawReply(FuseChannel&, const iovec[], size_t) const {
  // Not implemented yet.
  throwNotImplemented();
}

} // namespace facebook::eden

#endif
