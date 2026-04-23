CC ?= gcc
SL ?= sl

# HGPROF=noop disables the Python profiler, but the native profiler isn't affected.
# `debugcurrentexe` bypasses wrappers.
repro: libslowunmap.so
	LD_PRELOAD=./libslowunmap.so HGPROF=noop $$($(SL) debugcurrentexe) debugshell --profile stress_pymalloc.py

# reproduce under gdb
gdb: libslowunmap.so
	gdb -ex 'set env LD_PRELOAD=./libslowunmap.so' -ex 'set env HGPROF=noop' -ex run --args $$($(SL) debugcurrentexe) debugshell --profile stress_pymalloc.py

# reproduce under lldb
lldb: libslowunmap.so
	lldb -o 'settings set target.env-vars LD_PRELOAD=./libslowunmap.so HGPROF=noop' -o run -- $$($(SL) debugcurrentexe) debugshell --profile stress_pymalloc.py

libslowunmap.so: slow_munmap.c
	$(CC) $^ $(CFLAGS) -fPIC -ldl -shared -o $@

clean:
	rm -f libslowunmap.so
