/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include <cpptoml.h>
#include <memory>

#include "eden/common/utils/PathFuncs.h"

namespace facebook::eden {

// cpptoml::parse_file uses std::ifstream with a narrow string path, which on
// Windows uses the ANSI code page and cannot open paths with non-Latin
// characters. This wrapper opens the file with a wide string path on Windows.
std::shared_ptr<cpptoml::table> parseTomlFile(const AbsolutePath& path);

} // namespace facebook::eden
