/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/testharness/FakePrivHelper.h"

#include <folly/File.h>
#include <folly/futures/Future.h>
#include <utility>

#include "eden/fs/utils/NotImplemented.h"

#ifndef _WIN32
#include "eden/fs/testharness/FakeFuse.h"
#endif // _WIN32

using folly::File;
using folly::Future;
using folly::makeFuture;
using folly::Unit;
using std::runtime_error;
using std::string;

namespace facebook::eden {

FakeFuseMountDelegate::FakeFuseMountDelegate(
    AbsolutePath mountPath,
    std::shared_ptr<FakeFuse> fuse) noexcept
    : mountPath_{std::move(mountPath)}, fuse_{std::move(fuse)} {}

folly::Future<folly::File> FakeFuseMountDelegate::fuseMount() {
#ifndef _WIN32
  if (fuse_->isStarted()) {
    throwf<std::runtime_error>(
        "got request to create FUSE mount {}, "
        "but this mount is already running",
        mountPath_);
  }
  return fuse_->start();
#else
  NOT_IMPLEMENTED();
#endif
}

folly::Future<folly::Unit> FakeFuseMountDelegate::fuseUnmount() {
#ifndef _WIN32
  return folly::makeFutureWith([this] {
    wasFuseUnmountEverCalled_ = true;
    if (!fuse_->isStarted()) {
      throwf<std::runtime_error>(
          "got request to unmount {}, "
          "but this mount is not mounted",
          mountPath_);
    }
    return fuse_->close();
  });
#else
  NOT_IMPLEMENTED();
#endif
}

bool FakeFuseMountDelegate::wasFuseUnmountEverCalled() const noexcept {
  return wasFuseUnmountEverCalled_;
}

FakePrivHelper::MountDelegate::~MountDelegate() = default;

void FakePrivHelper::registerMount(
    AbsolutePathPiece mountPath,
    std::shared_ptr<FakeFuse> fuse) {
  registerMountDelegate(
      mountPath,
      std::make_shared<FakeFuseMountDelegate>(
          AbsolutePath{mountPath}, std::move(fuse)));
}

void FakePrivHelper::registerMountDelegate(
    AbsolutePathPiece mountPath,
    std::shared_ptr<MountDelegate> mountDelegate) {
  auto ret =
      mountDelegates_.emplace(mountPath.asString(), std::move(mountDelegate));
  if (!ret.second) {
    throwf<std::range_error>("mount {} already defined", mountPath);
  }
}

void FakePrivHelper::attachEventBase(folly::EventBase* /* eventBase */) {}

void FakePrivHelper::detachEventBase() {}

Future<File> FakePrivHelper::fuseMount(
    folly::StringPiece mountPath,
    bool /*readOnly*/,
    folly::StringPiece /*vfsType*/) {
  return getMountDelegate(mountPath)->fuseMount();
}

Future<Unit> FakePrivHelper::nfsMount(
    folly::StringPiece /*mountPath*/,
    const NFSMountOptions& /*options*/) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::nfsMount() not implemented"));
}

folly::Future<folly::Unit> FakePrivHelper::nfsUnmount(
    folly::StringPiece /*mountPath*/) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::nfsUnmount() not implemented"));
}

Future<Unit> FakePrivHelper::fuseUnmount(
    folly::StringPiece mountPath,
    const UnmountOptions& /* options */) {
  return folly::makeFutureWith(
      [&] { return getMountDelegate(mountPath)->fuseUnmount(); });
}

Future<Unit> FakePrivHelper::bindMount(
    folly::StringPiece /* clientPath */,
    folly::StringPiece /* mountPath */) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::bindMount() not implemented"));
}

folly::Future<folly::Unit> FakePrivHelper::bindUnMount(
    folly::StringPiece /* mountPath */) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::bindUnMount() not implemented"));
}

Future<Unit> FakePrivHelper::takeoverShutdown(
    folly::StringPiece /* mountPath */) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::takeoverShutdown() not implemented"));
}

Future<Unit> FakePrivHelper::takeoverStartup(
    folly::StringPiece /* mountPath */,
    const std::vector<std::string>& /* bindMounts */) {
  return makeFuture<Unit>(
      runtime_error("FakePrivHelper::takeoverStartup() not implemented"));
}

Future<Unit> FakePrivHelper::setLogFile(folly::File /* logFile */) {
  return makeFuture();
}

Future<Unit> FakePrivHelper::setMemoryPriorityForProcess(
    pid_t /* pid */,
    int /* priority */) {
  return makeFuture<Unit>(runtime_error(
      "FakePrivHelper::setMemoryPriorityForProcess() not implemented"));
}

int FakePrivHelper::stop() {
  return 0;
}

std::shared_ptr<FakePrivHelper::MountDelegate> FakePrivHelper::getMountDelegate(
    folly::StringPiece mountPath) {
  auto it = mountDelegates_.find(mountPath.str());
  if (it == mountDelegates_.end()) {
    throwf<std::range_error>(
        "got request to for FUSE mount {}, "
        "but no test FUSE endpoint defined for this path",
        mountPath);
  }
  return it->second;
}

folly::Future<folly::Unit> FakePrivHelper::setDaemonTimeout(
    std::chrono::nanoseconds /* duration */) {
  return folly::Unit{};
}

folly::Future<folly::Unit> FakePrivHelper::setUseEdenFs(bool /* useEdenFs */) {
  return folly::unit;
}

folly::Future<pid_t> FakePrivHelper::getServerPid() {
  return -1;
}

folly::Future<pid_t> FakePrivHelper::startFam(
    const std::vector<std::string>& /* paths */,
    const std::string& /* tmpOutputPath */,
    const std::string& /* specifiedOutputPath */,
    const bool /* shouldUpload */) {
  return makeFuture<pid_t>(
      runtime_error("FakePrivHelper::startFam() not implemented"));
}

folly::Future<StopFileAccessMonitorResponse> FakePrivHelper::stopFam() {
  return makeFuture<StopFileAccessMonitorResponse>(
      runtime_error("FakePrivHelper::stopFam() not implemented"));
}

} // namespace facebook::eden
