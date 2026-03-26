#require rmcwd normal-layout
#debugruntest-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo
Note: With buck build the sl script can be a wrapper that runs shell commands.
That can print extra noisy outputs like " shell-init: error retrieving current
directory: getcwd: cannot access parent directories". So we skip this test for
buck build.

(rmcwd is incompatible with Python tests right now - os.getcwd() will fail)

  $ A=$TESTTMP/a
  $ mkdir $A
  $ cd $A

Removed cwd

  $ rmdir $A

  $ sl debug-args
  abort: cannot get current directory: * (glob)
  [74]

Recreated cwd

  $ mkdir $A
  $ sl debug-args a
  (warning: the current directory was recreated; consider running 'cd $PWD' to fix your shell)
  ["a"]
