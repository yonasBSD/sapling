
#require no-eden


  $ configure modern
  $ enable rebase

  $ newclientrepo

  $ drawdag <<EOS
  > B     # B/foo = changed
  > |     # B/bar = a\nb\nc\nd\n
  > |  C  # C/foo = (removed)
  > | /   # C/bar = b\nc\nd\ne\n
  > |/    # A/foo = foo
  > A     # A/bar = b\nc\nd\n
  > EOS

  $ sl go -q $C

Test some error handling:
  $ sl debugpickmergetool --tool "if('foo', other, local)"
  sl: parse error: merge script produced 'remotefilectx' instead of 'str'
  [255]

  $ sl debugpickmergetool --tool 'if("oops'
  sl: parse error at 4: unterminated string
  [255]

  $ sl debugpickmergetool --tool 'if(foo, bar, baz'
  sl: parse error at 16: unexpected token: end
  [255]

Test that we can vary merge tool based on isabsent():

  $ sl rebase -r $C -d $B --tool "if(isabsent(other), :other, :merge)"
  rebasing 43c61a1c14d8 "C"
  merging bar

foo was deleted via :other
  $ ls foo
  ls: foo: $ENOENT$
  [1]

bar was merged via :merge
  $ cat bar
  a
  b
  c
  d
  e

