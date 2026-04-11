/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/nfs/rpc/RpcServer.h"

#ifndef _WIN32
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

#include <cstring>

#include <folly/executors/ManualExecutor.h>
#include <folly/io/IOBuf.h>
#include <folly/io/IOBufQueue.h>
#include <gtest/gtest.h>

#include "eden/common/telemetry/NullStructuredLogger.h"
#include "eden/fs/nfs/NfsdRpc.h"
#include "eden/fs/nfs/rpc/Rpc.h"

namespace {

using namespace facebook::eden;

class TestServerProcessor : public RpcServerProcessor {};

class TestFastPathProcessor : public RpcServerProcessor {
 public:
  bool shouldFastPathRPCs() const override {
    return true;
  }
  bool isUnimplementedProc(uint32_t proc) const override {
    return proc >= 22;
  }
};

std::unique_ptr<folly::IOBuf> buildRpcRequest(uint32_t xid, uint32_t proc) {
  folly::IOBufQueue queue{folly::IOBufQueue::cacheChainLength()};
  folly::io::QueueAppender ser(&queue, 256);

  XdrTrait<uint32_t>::serialize(ser, 0); // fragment header placeholder
  rpc_msg_call call{
      xid,
      msg_type::CALL,
      call_body{
          kRPCVersion,
          kNfsdProgNumber,
          kNfsd3ProgVersion,
          proc,
          opaque_auth{auth_flavor::AUTH_NONE, {}},
          opaque_auth{auth_flavor::AUTH_NONE, {}},
      },
  };
  XdrTrait<rpc_msg_call>::serialize(ser, call);

  auto len = static_cast<uint32_t>(queue.chainLength() - sizeof(uint32_t));
  auto buf = queue.move();
  auto* header = reinterpret_cast<uint32_t*>(buf->writableData());
  *header = folly::Endian::big(len | 0x80000000);
  return buf;
}

std::unique_ptr<folly::IOBuf> buildNullRpcRequest(uint32_t xid) {
  return buildRpcRequest(xid, 0);
}

struct RpcServerTest : ::testing::Test {
  std::shared_ptr<RpcServer> createTestServer(
      std::shared_ptr<RpcServerProcessor> proc,
      std::shared_ptr<folly::Executor> executor =
          folly::getUnsafeMutableGlobalCPUExecutor()) {
    return RpcServer::create(
        std::move(proc),
        &evb,
        std::move(executor),
        std::make_shared<NullStructuredLogger>(),
        /*maximumInFlightRequests=*/1000,
        /*highNfsRequestsLogInterval=*/std::chrono::minutes{10});
  }

  std::shared_ptr<RpcServer> createTestServerWithManualExecutor(
      std::shared_ptr<RpcServerProcessor> proc) {
    manualExecutor_ = std::make_shared<folly::ManualExecutor>();
    return createTestServer(std::move(proc), manualExecutor_);
  }

#ifndef _WIN32
  /**
   * Create a connected socketpair, initialize the server with one end,
   * and return the client fd. Caller must close the returned fd.
   */
  int connectClient(RpcServer& server) {
    int fds[2];
    EXPECT_EQ(0, socketpair(AF_UNIX, SOCK_STREAM, 0, fds));
    server.initializeConnectedSocket(folly::File(fds[0], true));
    return fds[1];
  }

  /**
   * Write a serialized RPC request to the client fd and drive the
   * EventBase so it reads the bytes and processes any inline fast-path
   * replies (null, PROC_UNAVAIL, JUKEBOX) before dispatching to the
   * thread pool.
   */
  void sendRequest(int clientFd, std::unique_ptr<folly::IOBuf> request) {
    auto bytes = request->coalesce();
    ASSERT_EQ(
        static_cast<ssize_t>(bytes.size()),
        write(clientFd, bytes.data(), bytes.size()));
    evb.loopOnce();
  }

  /**
   * Poll for data on the client fd. Returns true if data is available
   * within @p timeoutMs milliseconds. On a Unix socketpair the reply
   * is local and arrives in microseconds; callers use a generous
   * timeout as a safety net so a broken test fails with a clear
   * message instead of hanging the test runner.
   */
  bool pollForReply(int clientFd, int timeoutMs) {
    struct pollfd pfd{};
    pfd.fd = clientFd;
    pfd.events = POLLIN;
    return poll(&pfd, 1, timeoutMs) > 0;
  }

  /**
   * Read a reply from the client fd. Assumes a single read() returns
   * the complete reply — safe on Unix socketpairs with small messages
   * but would need a loop for TCP or replies larger than 256 bytes.
   */
  std::vector<uint8_t> readReply(int clientFd) {
    uint8_t buf[256];
    auto nread = read(clientFd, buf, sizeof(buf));
    EXPECT_GT(nread, 0);
    return std::vector<uint8_t>(buf, buf + nread);
  }

  /**
   * Send an RPC request and wait for the reply on the EventBase.
   * Returns the raw reply bytes. Asserts that a reply arrives within
   * the timeout.
   */
  std::vector<uint8_t> sendAndReceive(
      int clientFd,
      std::unique_ptr<folly::IOBuf> request,
      const char* failMsg = "Expected an RPC reply") {
    sendRequest(clientFd, std::move(request));
    EXPECT_TRUE(pollForReply(clientFd, 1000)) << failMsg;
    return readReply(clientFd);
  }

  /**
   * Read a big-endian uint32_t from a raw reply at the given byte offset.
   */
  static uint32_t readBigEndianU32(
      const std::vector<uint8_t>& data,
      size_t offset) {
    EXPECT_GE(data.size(), offset + 4);
    uint32_t val;
    memcpy(&val, data.data() + offset, sizeof(val));
    return folly::Endian::big(val);
  }

  /**
   * Clean up: close client fd, reset server, drain EventBase.
   */
  void cleanup(int clientFd, std::shared_ptr<RpcServer>& server) {
    close(clientFd);
    server.reset();
    evb.loopOnce();
  }
#endif // !_WIN32

  folly::EventBase evb;
  std::shared_ptr<folly::ManualExecutor> manualExecutor_;
};

TEST_F(RpcServerTest, takeover_before_initialize) {
  auto server = createTestServer(std::make_shared<TestServerProcessor>());

  auto takeover = server->takeoverStop();
  evb.drive();
  EXPECT_TRUE(takeover.isReady());
}

TEST_F(RpcServerTest, takeover_after_initialize) {
  auto server = createTestServer(std::make_shared<TestServerProcessor>());

  folly::SocketAddress addr;
  addr.setFromIpPort("::0", 0);
  server->initialize(addr);

  auto takeover = server->takeoverStop();
  evb.drive();
  EXPECT_TRUE(takeover.isReady());
}

TEST_F(RpcServerTest, takeover_from_takeover) {
  auto server = createTestServer(std::make_shared<TestServerProcessor>());

  folly::SocketAddress addr;
  addr.setFromIpPort("::0", 0);
  server->initialize(addr);

  auto takeover = server->takeoverStop();
  evb.drive();
  EXPECT_TRUE(takeover.isReady());

  server.reset();
  evb.drive();

  auto newServer = createTestServer(std::make_shared<TestServerProcessor>());
  newServer->initializeServerSocket(std::move(takeover).get());

  takeover = newServer->takeoverStop();
  evb.drive();
  EXPECT_TRUE(takeover.isReady());
}

#ifndef _WIN32
// Tests below use Unix socketpair/poll APIs not available on Windows.

TEST_F(RpcServerTest, null_rpc_bypasses_thread_pool) {
  auto server = createTestServerWithManualExecutor(
      std::make_shared<TestFastPathProcessor>());
  auto clientFd = connectClient(*server);

  auto reply = sendAndReceive(
      clientFd,
      buildNullRpcRequest(42),
      "Null RPC reply should arrive without needing the thread pool");

  EXPECT_EQ(readBigEndianU32(reply, 4), 42u); // xid
  EXPECT_EQ(readBigEndianU32(reply, 8), 1u); // msg_type::REPLY
  cleanup(clientFd, server);
}

TEST_F(RpcServerTest, proc_unavail_fast_path) {
  auto server = createTestServerWithManualExecutor(
      std::make_shared<TestFastPathProcessor>());
  auto clientFd = connectClient(*server);

  // Send an unknown proc (99) which isUnimplementedProc returns true for.
  auto reply = sendAndReceive(
      clientFd,
      buildRpcRequest(55, /*proc=*/99),
      "PROC_UNAVAIL reply should arrive without needing the thread pool");

  EXPECT_EQ(readBigEndianU32(reply, 4), 55u); // xid
  EXPECT_EQ(readBigEndianU32(reply, 8), 1u); // msg_type::REPLY
  // accept_stat::PROC_UNAVAIL = 3, at offset 24
  EXPECT_EQ(readBigEndianU32(reply, 24), 3u); // accept_stat::PROC_UNAVAIL
  cleanup(clientFd, server);
}

TEST_F(RpcServerTest, normal_proc_not_fast_pathed) {
  auto server = createTestServerWithManualExecutor(
      std::make_shared<TestFastPathProcessor>());
  auto clientFd = connectClient(*server);

  sendRequest(clientFd, buildRpcRequest(77, /*proc=*/1));

  // No inline reply — proc=1 is neither null nor unimplemented, so it
  // should be dispatched to the thread pool, not fast-pathed.
  EXPECT_FALSE(pollForReply(clientFd, 100))
      << "Normal proc should not get an inline reply";

  // The dispatch pipeline has multiple hops through the ManualExecutor
  // and EventBase. Alternate cranking both until the reply arrives.
  for (int i = 0; i < 20; ++i) {
    manualExecutor_->run();
    evb.loopOnce(EVLOOP_NONBLOCK);
  }

  EXPECT_TRUE(pollForReply(clientFd, 1000))
      << "Reply should arrive after cranking the thread pool";

  cleanup(clientFd, server);
}

#endif // !_WIN32

} // namespace
