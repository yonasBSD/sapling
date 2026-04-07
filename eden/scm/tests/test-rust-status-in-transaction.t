TODO: Remove the inprocess-hg-incompatible. This test requires launching hg
from dbsh, which doesn't work on Windows because at that point the PATH only
contains TESTTMP/bin, which doesn't include the Python DLLs required for
launching Sapling. If one tries to run sl from there it errors out with error
code 0xC0000135.
#inprocess-hg-incompatible
#require fsmonitor no-eden

  $ newclientrepo repo
  $ sl st
  $ sl debugtreestate list

Sanity that dirstate is normally updated by status:
  $ touch foo
  $ sl st
  ? foo
  $ sl debugtreestate list
  foo: * NEED_CHECK  (glob)

Mutate dirstate in a transaction - should not be visible outside transaction:
  $ sl dbsh <<EOF
  > with repo.wlock(), repo.lock(), repo.transaction("foo"):
  >   repo.dirstate.add("foo")
  >   print("pending adds:", repo.status().added)
  >   import subprocess
  >   print("external adds:", subprocess.run(["hg", "st", "-an"], check=True, capture_output=True).stdout.strip().decode() or "<none>")
  > EOF
  pending adds: ['foo']
  external adds: <none>

Now it should be visible
  $ sl st
  A foo

Make sure things are okay if Rust flushes the treestate and then Python makes a change:
  $ touch bar
  $ sl dbsh <<EOF
  > with repo.wlock(), repo.lock(), repo.transaction("foo"):
  >   # This will trigger treestate flush adding "bar".
  >   repo.status()
  >   import subprocess
  >   print("external unknown:", subprocess.run(["hg", "st", "-un"], check=True, capture_output=True).stdout.strip().decode() or "<none>")
  >   # Make another dirstate change - this needs to get flushed properly.
  >   repo.dirstate.add("bar")
  > EOF
  external unknown: bar

  $ sl st
  A bar
  A foo
