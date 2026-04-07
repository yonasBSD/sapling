
#require no-icasefs no-eden

  $ eagerepo
test file addition with colliding case

  $ sl init repo1
  $ cd repo1
  $ echo a > a
  $ echo A > A
  $ sl add a
  $ sl st
  A a
  ? A
  $ sl add --config ui.portablefilenames=abort A
  abort: possible case-folding collision for A
  [255]
  $ sl st
  A a
  ? A
  $ sl add A
  warning: possible case-folding collision for A
  $ sl st
  A A
  A a
  $ sl forget A
  $ sl st
  A a
  ? A
  $ sl add --config ui.portablefilenames=no A
  $ sl st
  A A
  A a
  $ mkdir b
  $ touch b/c b/D
  $ sl add b
  adding b/D
  adding b/c
  $ touch b/d b/C
  $ sl add b/C
  warning: possible case-folding collision for b/C
  $ sl add b/d
  warning: possible case-folding collision for b/d
  $ touch b/a1 b/a2
  $ sl add b
  adding b/a1
  adding b/a2
  $ touch b/A2 b/a1.1
  $ sl add b/a1.1 b/A2
  warning: possible case-folding collision for b/A2
  $ touch b/f b/F
  $ sl add b/f b/F
  warning: possible case-folding collision for b/f
  $ touch g G
  $ sl add g G
  warning: possible case-folding collision for g
  $ mkdir h H
  $ touch h/x H/x
  $ sl add h/x H/x
  warning: possible case-folding collision for h/x
  $ touch h/s H/s
  $ sl add h/s
  $ sl add H/s
  warning: possible case-folding collision for H/s

case changing rename must not warn or abort

  $ echo c > c
  $ sl ci -qAmx
  $ sl mv c C
  $ cd ..
