/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/telemetry/StackTraceUploader.h"

#include <algorithm>

#include <gtest/gtest.h>

namespace facebook::eden {

TEST(StackTraceUploaderTest, generateKeyAndUrlFormat) {
  auto key = StackTraceUploader::generateKey();
  // Key format: "flat/" + 32 hex characters
  EXPECT_EQ(key.substr(0, 5), "flat/");
  auto rest = key.substr(5);
  EXPECT_EQ(rest.size(), 32);
  EXPECT_TRUE(std::all_of(rest.begin(), rest.end(), ::isxdigit))
      << "Expected hex string, got: " << rest;

  // URL should embed the bucket name and the generated key
  auto url = StackTraceUploader::keyToUrl(key);
  EXPECT_EQ(url, "manifold://edenfs-errors-stacktraces/" + key);
}

TEST(StackTraceUploaderTest, generateKeyIsUnique) {
  auto key1 = StackTraceUploader::generateKey();
  auto key2 = StackTraceUploader::generateKey();
  EXPECT_NE(key1, key2);
}

} // namespace facebook::eden
