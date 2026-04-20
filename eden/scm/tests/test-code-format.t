
#require no-eden no-windows

  $ configure modernclient

Create a fake formatter that prepends "===formatted===" to each file (idempotent).
  $ cat > "$TESTTMP/formatter.py" <<EOF
  > import sys, os
  > for line in sys.stdin:
  >     fn = line.strip()
  >     if fn and os.path.isfile(fn):
  >         data = open(fn).read()
  >         if not data.startswith("===formatted===\n"):
  >             open(fn, "w").write("===formatted===\n" + data)
  > EOF

Setup repo:
  $ newclientrepo
  $ setconfig hooks.pre-commit.sl_code_format=python:sapling.agent.fb.code_format.main
  $ setconfig hooks.pre-amend.sl_code_format=python:sapling.agent.fb.code_format.main
  $ setconfig fix.always-enable-code-format=True
  $ setconfig fix.code-format-command="sl debugpython $TESTTMP/formatter.py"

Test basic formatting on commit:
  $ echo "hello" > a.txt
  $ sl add a.txt
  $ sl commit -m "add a"
  running code formatter: '*' (glob)
  code formatter completed successfully in * secs (glob)
  $ cat a.txt
  ===formatted===
  hello

Formatter is idempotent - already formatted files are not modified:
  $ echo "more" >> a.txt
  $ sl amend
  running code formatter: '*' (glob)
  code formatter completed successfully in * secs (glob)
  $ cat a.txt
  ===formatted===
  hello
  more

Test formatting on amend with new file:
  $ echo "world" > b.txt
  $ sl add b.txt
  $ sl amend
  running code formatter: '*' (glob)
  code formatter completed successfully in * secs (glob)
  $ cat b.txt
  ===formatted===
  world

Test disabled via config:
  $ setconfig 'fix.enable-code-format=False'
  $ echo "not formatted" > c.txt
  $ sl add c.txt
  $ sl amend
  $ cat c.txt
  not formatted
Re-enable for subsequent tests:
  $ setconfig 'fix.enable-code-format=True'

Test skipped when not agent and always-enable is false:
  $ setconfig 'fix.always-enable-code-format=False'
  $ echo "not formatted either" > d.txt
  $ sl add d.txt
  $ sl amend
  $ cat d.txt
  not formatted either
Re-enable for subsequent tests:
  $ setconfig 'fix.always-enable-code-format=True'

Test max-files limit skips formatting:
  $ setconfig 'fix.code-format-max-files=1'
  $ echo "x" > e.txt
  $ echo "y" > f.txt
  $ sl add e.txt f.txt
  $ sl amend
  $ cat e.txt
  x
  $ setconfig 'fix.code-format-max-files=200'

Test max-file-size limit skips formatting:
  $ setconfig 'fix.code-format-max-file-size=10'
  $ echo "this is a long line that exceeds the size limit" > g.txt
  $ sl add g.txt
  $ sl amend
  $ cat g.txt
  this is a long line that exceeds the size limit
  $ setconfig 'fix.code-format-max-file-size=500000'

Test formatter failure aborts amend:
  $ cat > "$TESTTMP/fail_formatter.py" <<EOF
  > import sys; sys.exit(1)
  > EOF
  $ setconfig fix.code-format-command="sl debugpython $TESTTMP/fail_formatter.py"
  $ echo "h" > h.txt
  $ sl add h.txt
  $ sl amend
  running code formatter: '*' (glob)
  error: pre-amend.sl_code_format hook failed: code formatter failed with exit code 1. Run `*` manually to see details. (glob)
  
  abort: code formatter failed with exit code 1. Run `sl debugpython $TESTTMP/fail_formatter.py` manually to see details.
  
  [255]
