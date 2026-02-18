#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-strict

"""
Multiprocessing helpers for EdenFS CLI.

Re-derives native library directories from sys.path (which still contains
Buck2 link-tree paths even after the bootstrapper cleans LD_LIBRARY_PATH)
and sets them as LD_LIBRARY_PATH / DYLD_LIBRARY_PATH in os.environ so that
spawned child processes can find native .so/.dylib files like folly.iobuf.
"""

import multiprocessing
import multiprocessing.context
import os
import sys


def _native_lib_dirs() -> list[str]:
    """
    Collect valid directories from sys.path that may contain native libraries.

    Returns:
        List of absolute directory paths from sys.path.
    """
    dirs: list[str] = []
    for p in sys.path:
        abs_path = os.path.abspath(p)
        if os.path.isdir(abs_path):
            dirs.append(abs_path)
    return dirs


def _setup_library_paths() -> None:
    """
    Set platform-appropriate library search paths from sys.path entries.

    On Linux, sets LD_LIBRARY_PATH. On macOS, sets DYLD_LIBRARY_PATH.
    On Windows, calls os.add_dll_directory() for each directory.
    Called at import time so spawned children inherit the environment.
    """
    dirs = _native_lib_dirs()
    if not dirs:
        return

    if sys.platform == "win32":
        add_dll_directory = getattr(os, "add_dll_directory", None)
        if add_dll_directory is not None:
            for d in dirs:
                add_dll_directory(d)
    elif sys.platform == "darwin":
        existing = os.environ.get("DYLD_LIBRARY_PATH", "")
        combined = os.pathsep.join(dirs)
        if existing:
            combined = combined + os.pathsep + existing
        os.environ["DYLD_LIBRARY_PATH"] = combined
    else:
        existing = os.environ.get("LD_LIBRARY_PATH", "")
        combined = os.pathsep.join(dirs)
        if existing:
            combined = combined + os.pathsep + existing
        os.environ["LD_LIBRARY_PATH"] = combined


_setup_library_paths()


def get_context() -> multiprocessing.context.DefaultContext:
    """
    Return the platform-default multiprocessing context.

    With _setup_library_paths() having propagated native library dirs into
    the environment, spawned children can find native modules without
    needing to force fork.

    Returns:
        The default multiprocessing context for the current platform.
    """
    # pyre-ignore[7]: multiprocessing.get_context() is typed as BaseContext
    # but actually returns DefaultContext at runtime.
    return multiprocessing.get_context()
