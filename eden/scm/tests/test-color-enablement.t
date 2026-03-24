
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig alias.testcolor="debugtemplate '{label(\"green\", \"output\n\")}'"

  $ HGPLAINEXCEPT=alias sl testcolor
  output

  $ HGPLAINEXCEPT=alias sl testcolor --color always
  output

  $ sl testcolor --color always
  \x1b[32moutput\x1b[39m (esc)

  $ sl testcolor --color yes
  \x1b[32moutput\x1b[39m (esc)

  $ sl testcolor --color auto
  output

  $ HGPLAINEXCEPT=color,alias sl testcolor --color always
  \x1b[32moutput\x1b[39m (esc)

  $ sl testcolor --config ui.color=always
  \x1b[32moutput\x1b[39m (esc)

  $ sl testcolor --config ui.color=t
  output
