# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-strict

"""
utilities to support the git repo tool

References:
    https://gerrit.googlesource.com/git-repo
"""

import weakref
from typing import List

from .git import Submodule

# Whether to be compatible with `.repo/`.
GREPO_REQUIREMENT = "grepo"


def getgreposubmodules(ctx, repo) -> List[Submodule]:
    """Synthesize Submodule objects from the parent manifest for Grepo repos.

    Conceptually, grepo projects are very similar to Git submodules. Rust tree
    resolver synthesizes them into tree manifest as GitSubmodule (flag "m" in Python).
    This method synthesizes them into Python Submodule objects to plug into
    existing infrastructure.
    """
    parent = ctx.p1() if ctx.node() is None else ctx
    mf = parent.manifest()
    submodules = []
    for path in mf:
        if mf.flags(path) == "m":
            submodules.append(
                Submodule(path, "", path, True, weakref.proxy(repo)),
            )
    return submodules
