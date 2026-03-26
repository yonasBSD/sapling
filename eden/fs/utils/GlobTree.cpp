/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "GlobTree.h"

#include <folly/coro/Invoke.h>
#include <iomanip>

#include "eden/fs/config/EdenConfig.h"
#include "eden/fs/store/ObjectStore.h"

using folly::StringPiece;

namespace facebook::eden {

ImmediateFuture<folly::Unit> GlobTree::evaluate(
    std::shared_ptr<ObjectStore> store,
    const ObjectFetchContextPtr& context,
    RelativePathPiece rootPath,
    std::shared_ptr<const Tree> tree,
    PrefetchList* fileBlobsToPrefetch,
    ResultList* globResult,
    const RootId& originRootId) const {
  return evaluateImpl<GlobNodeImpl::TreeRoot, GlobNodeImpl::TreeRootPtr>(
             store.get(),
             context,
             rootPath,
             GlobNodeImpl::TreeRoot(std::move(tree)),
             fileBlobsToPrefetch,
             globResult,
             originRootId)
      // Make sure the store stays alive for the duration of globbing.
      .ensure([store] {});
}

folly::coro::now_task<folly::Unit> GlobTree::co_evaluate(
    std::shared_ptr<ObjectStore> store,
    const ObjectFetchContextPtr& context,
    RelativePathPiece rootPath,
    std::shared_ptr<const Tree> tree,
    PrefetchList* fileBlobsToPrefetch,
    ResultList* globResult,
    const RootId& originRootId) const {
  co_await evaluateImpl<GlobNodeImpl::TreeRoot, GlobNodeImpl::TreeRootPtr>(
      store.get(),
      context,
      rootPath,
      GlobNodeImpl::TreeRoot(std::move(tree)),
      fileBlobsToPrefetch,
      globResult,
      originRootId)
      // Make sure the store stays alive for the duration of globbing.
      .ensure([store] {})
      .semi();
  co_return folly::unit;
}

} // namespace facebook::eden
