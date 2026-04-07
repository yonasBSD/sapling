
  $ newclientrepo
  $ mkdir dir
  $ cd dir
  $ sl st foo path:bar 'glob:bar/baz*' 'bar*'
  warning: possible glob in non-glob pattern 'bar*', did you mean 'glob:bar*'?
  foo: $ENOENT$
  ../bar: $ENOENT$
  bar: $ENOENT$
  bar*: $ENOENT$ (no-windows !)
  bar*: The filename, directory name, or volume label syntax is incorrect. (os error 123) (windows !)

  $ touch oops
  $ sl st listfile:oops
  warning: empty listfile oops matches nothing
