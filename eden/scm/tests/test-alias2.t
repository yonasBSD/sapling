
#require no-eden


  $ eagerepo
Interesting corner cases.

command name matches global flag values

  $ setconfig ui.allowemptycommit=1

  $ sl init foo
  $ sl -R foo commit -m "This is foo\n"

  $ sl init log
  $ sl -R log commit -m "This is log\n"

  $ setconfig "alias.foo=log" "alias.log=log -T {desc} -r"

  $ sl -R foo foo tip
  This is foo\n (no-eol)
  $ sl -R log foo tip
  This is log\n (no-eol)
  $ sl -R foo log tip
  This is foo\n (no-eol)
  $ sl -R log log tip
  This is log\n (no-eol)
