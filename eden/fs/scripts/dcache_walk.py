#!/usr/bin/env drgn
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""Walk dcache tree under a mount point, showing page cache status.

Usage:
    [sudo [drgn]] dcache_walk.py /mnt/data
    [sudo [drgn]] dcache_walk.py /mnt/data --depth 5 --limit 500
"""

# @noautodeps

import argparse
import os
import sys

from drgn import container_of
from drgn.helpers.linux.fs import for_each_mount
from drgn.helpers.linux.list import hlist_for_each_entry


INDENT = "  "
PAGE_KB = os.sysconf("SC_PAGE_SIZE") // 1024

prog = prog  # noqa: F821


def get_hz():
    """Resolve kernel HZ (tick rate) for jiffies conversion."""
    try:
        return prog.constant("CONFIG_HZ")
    except LookupError:
        pass
    try:
        import gzip

        with gzip.open("/proc/config.gz", "rt") as f:
            for line in f:
                if line.startswith("CONFIG_HZ="):
                    return int(line.strip().split("=")[1])
    except FileNotFoundError:
        pass
    return 1000


def fmt_ttl(expiry, now, hz):
    remaining = expiry - now
    if remaining <= 0:
        return "expired"
    secs = remaining / hz
    if secs >= 365 * 24 * 3600:
        return "inf"
    if secs >= 24 * 3600:
        return f"{secs / (24 * 3600):.0f}d"
    if secs >= 3600:
        return f"{secs / 3600:.0f}h"
    if secs >= 60:
        return f"{secs / 60:.0f}m"
    return f"{secs:.0f}s"


def fuse_dentry_info(dentry, now, hz):
    # 64-bit: d_fsdata IS the jiffies64 expiry (not a pointer)
    # 32-bit: d_fsdata -> union fuse_dentry { u64 time; }
    expiry = dentry.d_fsdata.value_()
    return f" entry={fmt_ttl(expiry, now, hz)}"


FUSE_STATE_BITS = [
    "ADVISE_RDPLUS",
    "INIT_RDPLUS",
    "SIZE_UNSTABLE",
    "BAD",
    "BTIME",
    "CACHE_IO_MODE",
]


def fmt_fuse_state(state):
    names = [name for i, name in enumerate(FUSE_STATE_BITS) if state & (1 << i)]
    return "|".join(names) if names else f"0x{state:x}"


def fuse_inode_info(inode, now, hz):
    try:
        fi = container_of(inode, "struct fuse_inode", "inode")
    except LookupError:
        return ""
    nid = fi.nodeid.value_()
    nlookup = fi.nlookup.value_()
    attr_ttl = fmt_ttl(fi.i_time.value_(), now, hz)
    state = fi.state.value_()
    parts = f"nid={nid} ref={nlookup} attr={attr_ttl}"
    if state:
        parts += f" state={fmt_fuse_state(state)}"
    return f" {parts}"


def mount_path(mnt):
    """Reconstruct full path by walking mount hierarchy."""
    parts = []
    while True:
        dentry = mnt.mnt_mountpoint
        parent = mnt.mnt_parent
        root = parent.mnt.mnt_root
        while (
            dentry.value_() != root.value_()
            and dentry.value_() != dentry.d_parent.value_()
        ):
            parts.append(dentry.d_name.name.string_().decode(errors="replace"))
            dentry = dentry.d_parent
        if mnt.value_() == parent.value_():
            break
        mnt = parent
    return "/" + "/".join(reversed(parts)) if parts else "/"


def fmt_size(nrpages):
    kb = nrpages * PAGE_KB
    if kb >= 1024 * 1024:
        return f"{kb / (1024 * 1024):.1f}G"
    if kb >= 1024:
        return f"{kb / 1024:.1f}M"
    return f"{kb}K"


def walk_dcache(dentry, depth, max_depth, limit, count, jiffies_ctx=None):
    if depth > max_depth or count[0] >= limit:
        return

    for child in hlist_for_each_entry(
        "struct dentry", dentry.d_children.address_of_(), "d_sib"
    ):
        if count[0] >= limit:
            print(f"{INDENT * depth}... (limit {limit} reached)")
            return
        count[0] += 1

        name = child.d_name.name.string_().decode(errors="replace")
        inode_ptr = child.d_inode.value_()

        fuse_extra = fuse_dentry_info(child, *jiffies_ctx) if jiffies_ctx else ""

        if not inode_ptr:
            print(f"{INDENT * depth}{name}  (negative){fuse_extra}")
            continue

        inode = child.d_inode
        ino = inode.i_ino.value_()
        mode = inode.i_mode.value_()
        is_dir = (mode & 0o170000) == 0o040000
        nrpages = inode.i_mapping.nrpages.value_()

        tag = "d" if is_dir else "f"
        suffix = "/" if is_dir else ""
        cache = f"pages={nrpages} ({fmt_size(nrpages)})" if nrpages else "pages=0"
        fuse_extra += fuse_inode_info(inode, *jiffies_ctx) if jiffies_ctx else ""

        print(f"{INDENT * depth}{name}{suffix}  [{tag}] ino={ino} {cache}{fuse_extra}")

        if is_dir and depth < max_depth:
            walk_dcache(child, depth + 1, max_depth, limit, count, jiffies_ctx)


def find_mount(target):
    """Find mount by matching device number, then longest path prefix."""
    try:
        target_dev = os.stat(target).st_dev
    except OSError:
        target_dev = None

    best, best_path = None, ""
    for mnt in for_each_mount(prog["init_task"].nsproxy.mnt_ns):
        mp = mount_path(mnt)
        prefix = mp if mp == "/" else mp + "/"
        if not (target == mp or target.startswith(prefix)):
            continue
        if len(mp) < len(best_path):
            continue
        # Prefer device number match to avoid picking wrong mount (e.g. rootfs)
        dev = mnt.mnt.mnt_sb.s_dev.value_()
        best_dev = best.mnt.mnt_sb.s_dev.value_() if best else None
        if len(mp) == len(best_path) and best_dev == target_dev and dev != target_dev:
            continue
        best, best_path = mnt, mp
    return best, best_path


def resolve_path(dentry, components):
    """Walk dcache children to resolve a relative path. Returns (dentry, components) or (None, failed_components)."""
    for i, name in enumerate(components):
        for child in hlist_for_each_entry(
            "struct dentry", dentry.d_children.address_of_(), "d_sib"
        ):
            if child.d_name.name.string_() == name.encode():
                dentry = child
                break
        else:
            return None, components[: i + 1]
    return dentry, components


def main():
    parser = argparse.ArgumentParser(description="Walk dcache tree under a path")
    parser.add_argument("path", help="Any path (mount point auto-detected)")
    parser.add_argument(
        "--depth", type=int, default=3, help="Max recursion depth (default: 3)"
    )
    parser.add_argument(
        "--limit", type=int, default=200, help="Max entries to visit (default: 200)"
    )
    args = parser.parse_args()
    target = os.path.realpath(args.path)

    mnt, mnt_path = find_mount(target)
    if mnt is None:
        print(f"No mount found for: {target}", file=sys.stderr)
        sys.exit(1)

    sb = mnt.mnt.mnt_sb
    fstype = sb.s_type.name.string_().decode()
    start = mnt.mnt.mnt_root

    # Resolve relative path from mount root to target
    relpath = os.path.relpath(target, mnt_path) if target != mnt_path else ""
    components = relpath.split("/") if relpath and relpath != "." else []

    if components:
        start, resolved = resolve_path(start, components)
        if start is None:
            failed = "/".join(resolved)
            print(
                f"Path not in dcache: {mnt_path.rstrip('/')}/{failed}", file=sys.stderr
            )
            sys.exit(1)

    is_fuse = fstype in ("fuse", "fuseblk")
    jiffies_ctx = (prog["jiffies_64"].value_(), get_hz()) if is_fuse else None

    header = f"{mnt_path} ({fstype})"
    if components:
        header += f" {'/'.join(components)}"
    print(header)

    count = [0]
    walk_dcache(start, 1, args.depth, args.limit, count, jiffies_ctx)

    legend = (
        f"[d]=dir [f]=file  ino=inode  pages=page cache"
        f"  | depth={args.depth} limit={args.limit}"
    )
    if is_fuse:
        legend += "  | nid=FUSE nodeid  ref=nlookup  entry/attr=TTL"
    if sys.stderr.isatty():
        legend = f"\033[90m{legend}\033[0m"
    print(legend, file=sys.stderr)


main()
