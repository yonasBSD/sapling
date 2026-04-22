/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/model/TreeEntry.h"

#include <sys/stat.h>
#include <cstdint>

#include <folly/logging/xlog.h>

#include "eden/common/utils/EnumValue.h"
#include "eden/common/utils/TimeUtil.h"

namespace facebook::eden {

namespace {
// Platform-independent execute bit mask for tree entry type detection.
// On POSIX platforms, this matches S_IXUSR. On Windows, we use the same
// value to enable consistent executable file detection across platforms.
constexpr mode_t EXECUTE_BIT_MASK = 0000100;
} // namespace

template <typename T>
bool checkValueEqual(
    const std::optional<folly::Try<T>>& lhs,
    const std::optional<folly::Try<T>>& rhs) {
  if (!lhs.has_value() || !rhs.has_value()) {
    return lhs.has_value() == rhs.has_value();
  }
  if (lhs.value().hasException() || rhs.value().hasException()) {
    return lhs.value().hasException() == rhs.value().hasException();
  }
  return lhs.value().value() == rhs.value().value();
}

bool operator==(const EntryAttributes& lhs, const EntryAttributes& rhs) {
  return checkValueEqual(lhs.sha1, rhs.sha1) &&
      checkValueEqual(lhs.size, rhs.size) &&
      checkValueEqual(lhs.type, rhs.type) &&
      checkValueEqual(lhs.objectId, rhs.objectId) &&
      checkValueEqual(lhs.digestSize, rhs.digestSize) &&
      checkValueEqual(lhs.digestHash, rhs.digestHash) &&
      checkValueEqual(lhs.mtime, rhs.mtime) &&
      checkValueEqual(lhs.mode, rhs.mode) &&
      checkValueEqual(lhs.underAcl, rhs.underAcl) &&
      checkValueEqual(lhs.aclInfo, rhs.aclInfo);
}

bool operator!=(const EntryAttributes& lhs, const EntryAttributes& rhs) {
  return !(lhs == rhs);
}

bool operator==(
    const folly::Try<EntryAttributes>& lhs,
    const folly::Try<EntryAttributes>& rhs) {
  if (lhs.hasException()) {
    return rhs.hasException();
  }
  if (rhs.hasException()) {
    return lhs.hasException();
  }
  return rhs.value() == lhs.value();
}

mode_t modeFromTreeEntryType(TreeEntryType ft) {
  switch (ft) {
    case TreeEntryType::TREE:
      return S_IFDIR | 0755;
    case TreeEntryType::REGULAR_FILE:
      return S_IFREG | 0644;
    case TreeEntryType::EXECUTABLE_FILE:
      return S_IFREG | 0755;
    case TreeEntryType::SYMLINK:
      return S_IFLNK | 0755;
  }
  XLOGF(FATAL, "illegal file type {}", enumValue(ft));
}

bool compareTreeEntryType(
    std::optional<TreeEntryType> lhs,
    std::optional<TreeEntryType> rhs) {
  auto ignoreWindowsExecutableTypeForComparison =
      [](TreeEntryType ft) -> TreeEntryType {
    if (folly::kIsWindows) {
      return ft == TreeEntryType::EXECUTABLE_FILE ? TreeEntryType::REGULAR_FILE
                                                  : ft;
    }
    return ft;
  };

  if (!lhs.has_value() || !rhs.has_value()) {
    return lhs.has_value() == rhs.has_value();
  }
  return ignoreWindowsExecutableTypeForComparison(lhs.value()) ==
      ignoreWindowsExecutableTypeForComparison(rhs.value());
}

std::optional<TreeEntryType> treeEntryTypeFromMode(mode_t mode) {
  if (S_ISREG(mode)) {
    return mode & EXECUTE_BIT_MASK ? TreeEntryType::EXECUTABLE_FILE
                                   : TreeEntryType::REGULAR_FILE;
  } else if (S_ISLNK(mode)) {
    return TreeEntryType::SYMLINK;
  } else if (S_ISDIR(mode)) {
    return TreeEntryType::TREE;
  } else {
    return std::nullopt;
  }
}

std::string TreeEntry::toLogString(PathComponentPiece name) const {
  char fileTypeChar = '?';
  switch (type_) {
    case TreeEntryType::TREE:
      fileTypeChar = 'd';
      break;
    case TreeEntryType::REGULAR_FILE:
      fileTypeChar = 'f';
      break;
    case TreeEntryType::EXECUTABLE_FILE:
      fileTypeChar = 'x';
      break;
    case TreeEntryType::SYMLINK:
      fileTypeChar = 'l';
      break;
  }

  return fmt::format("({}, {}, {})", name, id_, fileTypeChar);
}

} // namespace facebook::eden
