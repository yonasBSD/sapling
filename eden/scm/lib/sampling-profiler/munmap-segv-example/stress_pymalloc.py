# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# @noautodeps


def work(n):
    _a = _b = _c = _d = _e = _f = _g = _h = [0] * 100
    if n > 0:
        return work(n - 1)
    return 0


N = 10

for i in range(N):
    print(f"stress: {i + 1}/{N}")

    for j in range(100):
        work(500)
