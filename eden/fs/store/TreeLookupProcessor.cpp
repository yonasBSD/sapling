/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/store/TreeLookupProcessor.h"
#include "eden/fs/config/EdenConfig.h"
#include "eden/fs/model/Tree.h"
#include "eden/fs/store/ObjectStore.h"

#include <folly/coro/Invoke.h>

namespace facebook::eden {

ImmediateFuture<std::variant<std::shared_ptr<const Tree>, TreeEntry>>
TreeLookupProcessor::next(std::shared_ptr<const Tree> tree) {
  using RetType = std::variant<std::shared_ptr<const Tree>, TreeEntry>;
  if (iter_ == iterRange_.end()) {
    return RetType{tree};
  }

  auto name = *iter_++;
  auto it = tree->find(name);

  if (it == tree->cend()) {
    return makeImmediateFuture<RetType>(
        std::system_error(ENOENT, std::generic_category()));
  }

  if (iter_ == iterRange_.end()) {
    if (it->second.isTree()) {
      return objectStore_->getTree(it->second.getObjectId(), context_)
          .thenValue(
              [](std::shared_ptr<const Tree> tree) -> RetType { return tree; });
    } else {
      return RetType{it->second};
    }
  } else {
    if (!it->second.isTree()) {
      return makeImmediateFuture<RetType>(
          std::system_error(ENOTDIR, std::generic_category()));
    } else {
      return objectStore_->getTree(it->second.getObjectId(), context_)
          .thenValue([this](std::shared_ptr<const Tree> tree) {
            return next(std::move(tree));
          });
    }
  }
}

ImmediateFuture<std::variant<std::shared_ptr<const Tree>, TreeEntry>>
getTreeOrTreeEntry(
    std::shared_ptr<const Tree> rootTree,
    RelativePathPiece path,
    std::shared_ptr<ObjectStore> objectStore,
    ObjectFetchContextPtr context) {
  if (objectStore->getEdenConfig()->enableCoroutinesPhase3.getValue()) {
    return ImmediateFuture{
        // @lint-ignore CLANGTIDY facebook-folly-coro-return-captures-local-var
        folly::coro::co_invoke(
            [](std::shared_ptr<const Tree> rootTree,
               RelativePath path,
               std::shared_ptr<ObjectStore> objectStore,
               ObjectFetchContextPtr context)
                -> folly::coro::Task<
                    std::variant<std::shared_ptr<const Tree>, TreeEntry>> {
              co_return co_await co_getTreeOrTreeEntry(
                  std::move(rootTree),
                  RelativePathPiece{path},
                  std::move(objectStore),
                  std::move(context));
            },
            std::move(rootTree),
            path.copy(),
            std::move(objectStore),
            context.copy())
            .semi()};
  }

  if (path.empty()) {
    return std::variant<std::shared_ptr<const Tree>, TreeEntry>{
        std::move(rootTree)};
  }

  auto processor = std::make_unique<TreeLookupProcessor>(
      path, std::move(objectStore), context.copy());
  auto future = processor->next(std::move(rootTree));
  return std::move(future).ensure([p = std::move(processor)] {});
}

folly::coro::now_task<std::variant<std::shared_ptr<const Tree>, TreeEntry>>
co_getTreeOrTreeEntry(
    std::shared_ptr<const Tree> rootTree,
    RelativePathPiece path,
    std::shared_ptr<ObjectStore> objectStore,
    ObjectFetchContextPtr context) {
  using RetType = std::variant<std::shared_ptr<const Tree>, TreeEntry>;
  if (path.empty()) {
    co_return RetType{std::move(rootTree)};
  }

  auto tree = std::move(rootTree);
  RelativePath ownedPath{path};
  auto components = ownedPath.components();
  auto iter = components.begin();

  while (iter != components.end()) {
    auto name = *iter++;
    auto it = tree->find(name);

    if (it == tree->cend()) {
      throw std::system_error(ENOENT, std::generic_category());
    }

    if (iter == components.end()) {
      // Last component
      if (it->second.isTree()) {
        tree =
            co_await objectStore->co_getTree(it->second.getObjectId(), context);
        co_return RetType{std::move(tree)};
      } else {
        co_return RetType{it->second};
      }
    } else {
      // Intermediate component — must be a tree
      if (!it->second.isTree()) {
        throw std::system_error(ENOTDIR, std::generic_category());
      }
      tree =
          co_await objectStore->co_getTree(it->second.getObjectId(), context);
    }
  }

  co_return RetType{std::move(tree)};
}

} // namespace facebook::eden
