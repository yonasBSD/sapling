/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// @noautodeps
#define _GNU_SOURCE
#include <dlfcn.h>
#include <unistd.h>

static int (*real_munmap)(void*, size_t) = NULL;

int munmap(void* addr, size_t length) {
  if (!real_munmap)
    real_munmap = dlsym(RTLD_NEXT, "munmap");
  usleep(10000); // sleep 10ms
  return real_munmap(addr, length);
}
