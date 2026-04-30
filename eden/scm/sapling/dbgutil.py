# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

"""
integration with a native debugger like lldb

Check https://lldb.llvm.org/python_api.html for APIs.

This file runs standalone by lldb's Python interpreter. It does not have access
to `bindings` or other Sapling modules, except for the `backtrace_all` function.
Do not import Sapling modules outside `backtrace_all`.

There are 2 ways to use this feature,
- Use `debugbt` command.
- Use `lldb -p <pid>`, then run `command script import ./dbgutil.py`,
  then use the `bta` command.
"""

import functools
import os
import struct
import subprocess
import sys


def backtrace_all(ui, pid: int):
    """write backtraces of all threads of the given pid.
    Runs inside Sapling Python environment.
    """
    import inspect
    import tempfile

    import bindings

    python_source = inspect.getsource(sys.modules["sapling.dbgutil"])

    with tempfile.TemporaryDirectory(prefix="saplinglldb") as dir:
        python_script_path = os.path.join(dir, "dbgutil.py")
        if ui.formatted:
            out_path = ""
        else:
            # Buffer output so we
            out_path = os.path.join(dir, "bta_output.txt")
        with open(python_script_path, "wb") as f:
            f.write(python_source.encode())
        args = [
            ui.config("ui", "lldb") or "lldb",
            "-b",
            "--source-quietly",
            "-o",
            f"command script import {python_script_path}",
            "-o",
            f"bta {pid}{out_path and ' ' + out_path}",
        ]
        env = {**os.environ, "OFFSET_SP_FRAME": str(bindings.backtrace.OFFSET_SP_FRAME)}
        subprocess.run(args, stdout=(subprocess.DEVNULL if out_path else None), env=env)
        if out_path:
            with open(out_path, "rb") as f:
                data = f.read()
                ui.writebytes(data)


def _lldb_backtrace_all_attach_pid(pid, write):
    """Attach to a pid and write its backtraces.
    Runs inside lldb Python environment, outside Sapling environment.
    """
    import lldb

    debugger = lldb.debugger
    target = debugger.CreateTarget("")
    process = target.AttachToProcessWithID(lldb.SBListener(), pid, lldb.SBError())
    try:
        _lldb_backtrace_all_for_process(target, process, write)
    finally:
        if sys.platform == "win32":
            # Attempt to resume the suspended process. "Detach()" alone does not
            # seem to resume it...
            debugger.SetAsync(True)
            process.Continue()
        process.Detach()


def read_offset(name):
    value_str = os.getenv(name)
    if not value_str:
        value_str = subprocess.check_output(
            [
                "sl",
                "debugpython",
                "-c",
                f"import bindings; print(bindings.backtrace.{name})",
            ],
            encoding="utf8",
        )
    return int(value_str)


def _lldb_backtrace_all_for_process(target, process, write):
    """Write backtraces for the given lldb target/process.
    Runs inside lldb Python environment, outside Sapling environment.
    """
    import lldb

    offset_sp = read_offset("OFFSET_SP_FRAME")

    if target.addr_size != 8:
        write("non-64-bit (%s) architecture is not yet supported\n" % target.addr_size)
        return

    def read_u64(address: int) -> int:
        """read u64 from an address"""
        return struct.unpack("Q", process.ReadMemory(address, 8, lldb.SBError()))[0]

    def resolve_frame(frame) -> str:
        """extract python stack info from a frame.
        The frame should be a Sapling_PyEvalFrame function call.
        """
        sp: int = frame.sp
        ptr_addr = None
        if offset_sp is not None:
            ptr_addr = sp + offset_sp
        if ptr_addr is not None:
            try:
                python_frame_address = read_u64(ptr_addr)
                return resolve_python_frame(python_frame_address)
            except Exception as e:
                return f"<error {e} {ptr_addr}>"
        return ""

    def resolve_python_frame(python_frame_address: int) -> str:
        # NOTE: `sapling_cext_evalframe_resolve_frame` needs the Python GIL
        # to be "safe". However, it is likely just reading a bunch of
        # objects (ex. frame, code, str) and those objects are not being
        # GC-ed (since the call stack need them). So it is probably okay.
        value = target.EvaluateExpression(
            f"(char *)(sapling_cext_evalframe_resolve_frame((size_t){python_frame_address}))"
        )
        return (value.GetSummary() or "").strip('"')

    for thread in process.threads:
        write(("%r\n") % thread)
        frames = []  # [(frame | None, line)]
        has_resolved_python_frame = False
        for i, frame in enumerate(thread.frames):
            name = frame.GetDisplayFunctionName()
            if name == "Sapling_PyEvalFrame":
                resolved = resolve_frame(frame)
                if resolved:
                    has_resolved_python_frame = True
                    # The "frame #i" format matches the repr(frame) style.
                    frames.append((None, f"  frame #{i}: {resolved}\n"))
                    continue
            if name:
                frames.append((frame, f"  {repr(frame)}\n"))
        if has_resolved_python_frame:
            # If any Python frame is resolved, strip out noisy frames like _PyEval_EvalFrameDefault.
            frames = [
                (frame, line)
                for frame, line in frames
                if not _is_cpython_function(frame)
            ]
        write("".join(line for _frame, line in frames))
        write("\n")


def _is_cpython_function(frame) -> bool:
    return frame is not None and "python" in (frame.module.file.basename or "").lower()


def _lldb_backtrace_all_command(debugger, command, exe_ctx, result, internal_dict):
    """lldb command: bta [pid] [PATH]. Write Python+Rust traceback to stdout or PATH."""
    args = command.split(" ", 1)
    if len(args) >= 1 and args[0]:
        pid = int(args[0])
        impl = functools.partial(_lldb_backtrace_all_attach_pid, pid)
    else:
        target = exe_ctx.target
        process = exe_ctx.process
        impl = functools.partial(_lldb_backtrace_all_for_process, target, process)

    path = args[1].strip() if len(args) >= 2 else None
    if path:
        with open(path, "w", newline="\n") as f:
            impl(f.write)
            f.flush()
    else:
        impl(sys.stdout.write)


def __lldb_init_module(debugger, internal_dict):
    # When imported by lldb 'command script import', this function is called.
    # Add a 'bta' command to call _lldb_backtrace_all.
    debugger.HandleCommand(
        f"command script add -f {__name__}._lldb_backtrace_all_command bta"
    )
