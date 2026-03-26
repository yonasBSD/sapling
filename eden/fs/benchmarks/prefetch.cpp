/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include <folly/io/async/EventBaseThread.h>
#include "eden/common/utils/PathFuncs.h"
#include "eden/common/utils/benchharness/Bench.h"
#include "eden/fs/benchmarks/bench_utils.h"
#include "eden/fs/service/gen-cpp2/EdenService.h"

DEFINE_string(query, "", "Glob query to run");
DEFINE_string(repo, "", "Repository to run the benchmark against");
DEFINE_string(root, "", "Root of the query");

namespace {

using namespace facebook::eden;
using namespace facebook::eden::benchmarks;

AbsolutePath validateArguments() {
  if (FLAGS_query.empty()) {
    throw std::invalid_argument("A query argument must be passed in");
  }

  if (FLAGS_repo.empty()) {
    throw std::invalid_argument("A repo must be passed in");
  }

  return canonicalPath(FLAGS_repo);
}

void eden_prefetch(benchmark::State& state) {
  auto path = validateArguments();

  auto socketPath = getEdenSocketPath(path);

  auto evbThread = folly::EventBaseThread();
  auto eventBase = evbThread.getEventBase();

  auto client = createEdenThriftClient(eventBase, socketPath);

  PrefetchParams param;
  param.mountPoint() = path.view();
  param.globs() = std::vector<std::string>{FLAGS_query};
  param.background() = false;
  param.returnPrefetchedFiles() = true;
  if (!FLAGS_root.empty()) {
    param.searchRoot() = FLAGS_root;
  }

  for (auto _ : state) {
    auto start = std::chrono::high_resolution_clock::now();
    auto result =
        client->semifuture_prefetchFilesV2(param).via(eventBase).get();
    auto end = std::chrono::high_resolution_clock::now();

    benchmark::DoNotOptimize(result);

    auto elapsed =
        std::chrono::duration_cast<std::chrono::duration<double>>(end - start);
    state.SetIterationTime(elapsed.count());
  }

  // Destroy the client on the EventBase thread to avoid
  // thread assertions in AsyncSocket/RocketClientChannel destructors.
  eventBase->runInEventBaseThreadAndWait([c = std::move(client)] {});
}

BENCHMARK(eden_prefetch)
    ->UseManualTime()
    ->Unit(benchmark::kMillisecond)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->Threads(16)
    ->Threads(32);

} // namespace

EDEN_BENCHMARK_MAIN();
