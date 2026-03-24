  $ export HGIDENTITY=sl
  $ eagerepo

interactive editor should abort in non-interactive mode
  $ newrepo
  $ echo foo > foo
  $ sl add foo
  $ sl st
  A foo
  $ HGEDITOR="echo hello >" sl commit --config experimental.allow-non-interactive-editor=false
  abort: cannot start editor in non-interactive mode to complete the 'commit' action
  (consider running 'commit' action from the command line)
  [255]
  $ HGEDITOR="echo hello >" sl commit --config experimental.allow-non-interactive-editor=true
  $ sl log -T "{desc}\n" -r .
  hello
  $ echo bar >> foo
  $ sl st
  M foo
  $ HGEDITOR="echo bar >" sl commit
  $ sl log -T "{desc}\n" -r .
  bar
