#require no-eden

  $ newclientrepo

Test ui.plain():

  $ sl debugshell -c 'print(sapling.ui.ui.plain())'
  False

  $ HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain())'
  True

  $ HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("alias"))'
  True

  $ HGPLAINEXCEPT=alias HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("alias"))'
  False

Multiple exceptions:

  $ HGPLAINEXCEPT=alias,color HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("alias"))'
  False

  $ HGPLAINEXCEPT=alias,color HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("color"))'
  False

  $ HGPLAINEXCEPT=alias,color HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("pager"))'
  True

strictflags is exempted by default:

  $ HGPLAIN=1 sl debugshell -c 'print(sapling.ui.ui.plain("strictflags"))'
  False

  $ HGPLAIN=+strictflags sl debugshell -c 'print(sapling.ui.ui.plain("strictflags"))'
  True

HGPLAINEXCEPT without HGPLAIN still activates plain mode:

  $ HGPLAINEXCEPT=alias sl debugshell -c 'print(sapling.ui.ui.plain())'
  True

  $ HGPLAINEXCEPT=alias sl debugshell -c 'print(sapling.ui.ui.plain("alias"))'
  False

  $ HGPLAINEXCEPT=alias sl debugshell -c 'print(sapling.ui.ui.plain("color"))'
  True
