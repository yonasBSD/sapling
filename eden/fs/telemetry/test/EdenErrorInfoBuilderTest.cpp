/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/telemetry/EdenErrorInfoBuilder.h"
#include <gtest/gtest.h>
#include <cerrno>
#include <system_error>

using namespace facebook::eden;

TEST(EdenErrorInfoTest, InitializeFuseEdenErrorInfoWithException) {
  std::runtime_error ex("fuse read failed");
  int line = __LINE__ + 1;
  auto info = EdenErrorInfo::fuse(ex, 42, "/mnt/repo").create();

  EXPECT_EQ(info.component, EdenComponent::Fuse);
  EXPECT_EQ(info.errorMessage, "fuse read failed");
  EXPECT_EQ(info.inode.value(), 42);
  EXPECT_EQ(info.mountPoint.value(), "/mnt/repo");
  EXPECT_FALSE(info.errorCode.has_value());
  EXPECT_NE(
      info.exceptionType.value().find("runtime_error"), std::string::npos);
  EXPECT_TRUE(info.stackTrace.has_value());
  auto& trace = info.stackTrace.value();
  EXPECT_NE(trace.find("EdenErrorInfoBuilderTest.cpp"), std::string::npos);
  EXPECT_NE(trace.find(":" + std::to_string(line) + " in "), std::string::npos);
  EXPECT_NE(trace.find("TestBody"), std::string::npos);
}

TEST(EdenErrorInfoTest, InitializeFuseEdenErrorInfoWithStringMessage) {
  auto info =
      EdenErrorInfo::fuse("inode failed to load", 99, "/mnt/repo").create();

  EXPECT_EQ(info.component, EdenComponent::Fuse);
  EXPECT_EQ(info.errorMessage, "inode failed to load");
  EXPECT_EQ(info.inode.value(), 99);
  EXPECT_FALSE(info.errorCode.has_value());
  EXPECT_FALSE(info.errorName.has_value());
  EXPECT_FALSE(info.exceptionType.has_value());
  EXPECT_TRUE(info.stackTrace.has_value());
  auto& loc = info.stackTrace.value();
  EXPECT_NE(loc.find("EdenErrorInfoBuilderTest.cpp"), std::string::npos)
      << "Expected source file in location, got: " << loc;
}

TEST(EdenErrorInfoTest, FuseErrorInfoOverridesErrorCodeAndName) {
  std::runtime_error ex("request timed out");
  auto info = EdenErrorInfo::fuse(ex, 123, "/mnt/repo")
                  .withErrorCode(ETIMEDOUT)
                  .withErrorName("ETIMEDOUT")
                  .create();

  EXPECT_EQ(info.component, EdenComponent::Fuse);
  EXPECT_EQ(info.errorMessage, "request timed out");
  EXPECT_EQ(info.inode.value(), 123);
  EXPECT_EQ(info.errorCode.value(), ETIMEDOUT);
  EXPECT_EQ(info.errorName.value(), "ETIMEDOUT");
  EXPECT_NE(
      info.exceptionType.value().find("runtime_error"), std::string::npos);
}

TEST(EdenErrorInfoTest, InitializeThriftEdenErrorInfoWithSystemError) {
  std::system_error ex(
      std::make_error_code(std::errc::permission_denied), "access denied");
  auto info = EdenErrorInfo::thrift(ex, "hg status").create();

  EXPECT_EQ(info.component, EdenComponent::Thrift);
  EXPECT_EQ(info.clientCommandName.value(), "hg status");
  EXPECT_TRUE(info.errorCode.has_value());
  EXPECT_TRUE(info.errorName.has_value());
  EXPECT_NE(info.exceptionType.value().find("system_error"), std::string::npos);
}
