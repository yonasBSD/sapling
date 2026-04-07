
#require no-fsmonitor no-eden

#require eol-in-paths no-eden

  $ eagerepo

https://bz.mercurial-scm.org/352

test issue352

  $ newclientrepo
  $ A=`printf 'he\rllo'`
  $ echo foo > "$A"
Don't error out if a naughty file happens to be present:
  $ sl add
  skipping invalid path 'he\rllo'
Do error out if the naughty file is explicitly referenced:
  $ sl add "$A"
  abort: Failed to validate "he\rllo". Invalid byte: 13.
  [255]
  $ sl ci -A -m m
  skipping invalid path 'he\rllo'
  skipping invalid path 'he\rllo'
  skipping invalid path 'he\rllo'
  nothing changed
  [1]
  $ rm "$A"
  $ echo foo > "hell
  > o"
  $ sl add
  skipping invalid path 'hell\no'
  $ sl ci -A -m m
  skipping invalid path 'hell\no'
  skipping invalid path 'hell\no'
  skipping invalid path 'hell\no'
  nothing changed
  [1]
  $ echo foo > "$A"
  $ sl debugwalk 2>&1 | sort
  skipping invalid path 'he\rllo'
  skipping invalid path 'hell\no'

  $ echo bla > quickfox
  $ sl add quickfox 2>&1  | sort
  skipping invalid path 'he\rllo'
  skipping invalid path 'hell\no'
  $ sl ci -m 2 2>&1 | sort
  skipping invalid path 'he\rllo'
  skipping invalid path 'he\rllo'
  skipping invalid path 'hell\no'
  skipping invalid path 'hell\no'
  $ A=`printf 'quick\rfox'`
  $ (sl cp quickfox "$A" 2>&1; echo "[$?]" 1>&2) | sort
  abort: Failed to validate "quick\rfox". Invalid byte: 13.
  [255]
  $ (sl mv quickfox "$A" 2>&1; echo "[$?]" 1>&2) | sort
  abort: Failed to validate "quick\rfox". Invalid byte: 13.
  [255]

https://bz.mercurial-scm.org/2036

  $ cd ..

test issue2039

  $ newclientrepo
  $ cat <<EOF >> $HGRCPATH
  > [extensions]
  > color =
  > [color]
  > mode = ansi
  > EOF
  $ A=`printf 'foo\nbar'`
  $ B=`printf 'foo\nbar.baz'`
  $ touch "$A"
  $ touch "$B"

  $ sl status --color=always 2>&1 | sed -e 's/foo\n/foo<NEWLINE>/'| sort
  skipping invalid filename: 'foo<NEWLINE>bar'
  skipping invalid filename: 'foo<NEWLINE>bar.baz'

  $ cd ..
