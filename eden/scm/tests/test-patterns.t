#require no-windows no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
Explore the semi-mysterious matchmod.match API

  $ newrepo
  $ mkdir 'a*1' 'a*2'
  $ touch 'a*1/a' 'a*2/b'
  $ sl ci -m 1 -A 'a*1/a' 'a*2/b' -q 2>&1 | sort
  warning: filename contains '*', which is reserved on Windows: 'a*1/a'
  warning: filename contains '*', which is reserved on Windows: 'a*2/b'
  warning: possible glob in non-glob pattern 'a*1/a', did you mean 'glob:a*1/a'?
  warning: possible glob in non-glob pattern 'a*2/b', did you mean 'glob:a*2/b'?

"patterns="

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*"])))))'
  []

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*1"])))))'
  []

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*/*"])))))'
  ['a*1/a', 'a*2/b']

"include="

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*"])))))'
  ['a*1/a', 'a*2/b']

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*1"])))))'
  ['a*1/a']

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*/*"])))))'
  ['a*1/a', 'a*2/b']

"patterns=" with "default='path'"

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*"], default="path")))))'
  []

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*1"], default="path")))))'
  ['a*1/a']

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", patterns=["a*/*"], default="path")))))'
  []

"include=" with "default='path'" (ex. "default=" has no effect on "include=")

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*"], default="path")))))'
  ['a*1/a', 'a*2/b']

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*1"], default="path")))))'
  ['a*1/a']

  $ sl dbsh -c 'ui.write("%s\n" % str(list(repo["."].walk(s.match.match(repo.root, "", include=["a*/*"], default="path")))))'
  ['a*1/a', 'a*2/b']

Give a hint if a pattern will traverse the entire repo.
  $ sl files 'glob:**/*.cpp' --config hint.ack-match-full-traversal=false
  hint[match-full-traversal]: the patterns "glob:**/*.cpp" may be slow since they traverse the entire repo (see "sl help patterns")
  [1]

No hint since the prefix avoids the full traversal.
  $ sl files 'glob:foo/**/*.cpp' --config hint.ack-match-full-traversal=false
  [1]

No hint when run from a sub-directory since it won't traverse the entire repo.
  $ mkdir foo
  $ cd foo
  $ sl files 'glob:**/*.cpp' --config hint.ack-match-full-traversal=false
  [1]
