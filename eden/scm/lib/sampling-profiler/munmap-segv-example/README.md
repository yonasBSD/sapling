Attempt to trigger SIGSEGV during sampling on Linux.

    *** Signal 11 (SIGSEGV) (0x7ff99580c018) received by PID 3500044 (pthread TID 0x7ff999a608c0) (linux TID 3500044) (code: address not mapped to object), stack trace: ***
        @ 00000000068c69fe folly::symbolizer::(anonymous namespace)::signalHandler(int, siginfo_t*, void*)
        @ 000000000004455f (unknown)
        @ 0000000000459674 PyUnstable_InterpreterFrame_GetCode
        @ 00000000119fa6f6 sapling_cext_evalframe_extract_code_lineno_from_frame
        @ 00000000119f7591 <backtrace_python::PythonSupplementalFrameResolver as backtrace_ext::SupplementalFrameResolver>::maybe_extract_supplemental_info
        @ 0000000011e31fcb sampling_profiler::signal_handler::signal_handler::{closure#0}
        @ 0000000006e07341 backtrace::backtrace::libunwind::trace::trace_fn
        @ 0000000000012158 _Unwind_Backtrace
        @ 0000000011e3245f sampling_profiler::signal_handler::signal_handler
        @ 000000000004455f (unknown)
        @ 0000000000125897 munmap
        @ 000000000040e1ba _PyEval_EvalFrameDefault
        @ 00000000119fa642 Sapling_PyEvalFrame
        @ 00000000002c2fa4 PyObject_Vectorcall
        @ 0000000000417eca _PyEval_EvalFrameDefault
        @ 00000000119fa642 Sapling_PyEvalFrame
        @ 00000000002c2fa4 PyObject_Vectorcall
        @ 0000000000417eca _PyEval_EvalFrameDefault

Related code path in cpython (3.12):

    _PyEval_EvalFrameDefault (ceval.c)
      _PyEvalFrameClearAndPop
        clear_thread_frame
          _PyThreadState_PopFrame (pystate.c)
            _PyObject_VirtualFree (obmalloc.c)
              _PyObject_Arena.free (might call munmap)

To increase chance of triggering the SIGSEGV,
- `LD_PRELOAD=libslowunmap.so`: slow down `munmap` so it's more likely hit by the sampling signal handler.
- A specially designed Python script that attempts to trigger `_PyObject_Arena.free`.

Run `make` to trigger the segfault. Set `SL` to the main `sl` executable.
