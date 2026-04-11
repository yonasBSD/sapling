/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <folly/fibers/Semaphore.h>
#include <cstdlib>
#include <memory>

namespace facebook::eden {

/**
 * RAII guard for a request permit. Releases the permit on destruction.
 *
 * Only RequestPermitVendor can construct instances via acquirePermit()
 * (blocking) or tryAcquirePermit() (non-blocking). The constructor stores
 * the semaphore reference; the caller is responsible for having already
 * acquired a token (via wait() or try_wait()).
 */
class RequestPermit {
 public:
  ~RequestPermit() {
    if (auto semPtr = sem_.lock()) {
      semPtr->signal();
    }
  }

  RequestPermit() = delete;
  RequestPermit(const RequestPermit&) = delete;
  RequestPermit& operator=(const RequestPermit&) = delete;
  RequestPermit(RequestPermit&&) = delete;
  RequestPermit& operator=(RequestPermit&&) = delete;

 private:
  explicit RequestPermit(std::weak_ptr<folly::fibers::Semaphore> sem)
      : sem_(std::move(sem)) {}

  std::weak_ptr<folly::fibers::Semaphore> sem_;

  friend class RequestPermitVendor;
};

/**
 * RequestPermitVendor generates RequestPermits which represent a resource
 * acquired from a semaphore. RequestPermits release the resource when
 * destructed. RequestPermitVendor has sole ownership over the underlying
 * semaphore. This can be added to any class that wishes to implement rate
 * limiting.
 *
 * Offers both a blocking acquirePermit() and a non-blocking
 * tryAcquirePermit(). It can also be extended to support a
 * co_acquirePermit() method, see folly::fibers::Semaphore::co_wait()
 * for more information.
 */
class RequestPermitVendor {
 public:
  explicit RequestPermitVendor(std::size_t limit)
      : sem_(std::make_shared<folly::fibers::Semaphore>(limit)) {}

  /**
   * This will block until a permit is available.
   */
  inline std::unique_ptr<RequestPermit> acquirePermit() {
    sem_->wait();
    return std::unique_ptr<RequestPermit>(new RequestPermit(sem_));
  }

  /**
   * Attempt to acquire a permit without blocking. Returns nullptr if no
   * capacity is available.
   */
  inline std::unique_ptr<RequestPermit> tryAcquirePermit() {
    if (!sem_->try_wait()) {
      return nullptr;
    }
    return std::unique_ptr<RequestPermit>(new RequestPermit(sem_));
  }

  /**
   * Get the configured max capacity of the underlying semaphore
   */
  inline std::size_t capacity() const {
    return sem_->getCapacity();
  }

  /**
   * Get the current available headroom of the underlying semaphore
   */
  inline std::size_t available() const {
    return sem_->getAvailableTokens();
  }

  /**
   * Get the current number of inflight requests
   */
  inline std::size_t inflight() const {
    return sem_->getCapacity() - sem_->getAvailableTokens();
  }

 private:
  std::shared_ptr<folly::fibers::Semaphore> sem_;
};

} // namespace facebook::eden
