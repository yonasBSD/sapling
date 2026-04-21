/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/config/TomlFileUtil.h"

#include <fstream>

namespace facebook::eden {

std::shared_ptr<cpptoml::table> parseTomlFile(const AbsolutePath& path) {
#ifdef _WIN32
  std::ifstream file{path.wide()};
#else
  std::ifstream file{path.c_str()};
#endif
  if (!file.is_open()) {
    throw cpptoml::parse_exception{
        path.asString() + " could not be opened for parsing"};
  }
  cpptoml::parser p{file};
  return p.parse();
}

} // namespace facebook::eden
