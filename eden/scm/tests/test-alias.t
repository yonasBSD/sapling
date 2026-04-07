
#require no-eden


  $ eagerepo

  $ HGFOO=BAR; export HGFOO
  $ readconfig <<'EOF'
  > [alias]
  > # should clobber ci but not commit (issue2993)
  > ci = version
  > myinit = init
  > mycommit = commit
  > optionalrepo = showconfig alias.myinit
  > cleanstatus = status -c
  > unknown = bargle
  > ambiguous = s
  > recursive = recursive
  > disabled = extorder
  > nodefinition =
  > noclosingquotation = '
  > no--cwd = status --cwd elsewhere
  > no-R = status -R elsewhere
  > no--repo = status --repo elsewhere
  > no--repository = status --repository elsewhere
  > no--config = status --config a.config=1
  > mylog = log
  > lognull = log -r null
  > shortlog = log --template '{node|short} | {date|isodate}\n'
  > positional = log --template '{$2} {$1} | {date|isodate}\n'
  > dln = lognull --debug
  > nousage = rollback
  > put = export -r 0 -o "$FOO/%R.diff"
  > blank = !echo
  > self = !echo $0
  > echoall = !echo "$@"
  > echo1 = !echo $1
  > echo2 = !echo $2
  > echo13 = !echo $1 $3
  > echotokens = !printf "%s\n" "$@"
  > count = !hg log -r "$@" --template=. | wc -c | sed -e 's/ //g'
  > mcount = !hg log $@ --template=. | wc -c | sed -e 's/ //g'
  > rt = root
  > idalias = id
  > idaliaslong = id
  > idaliasshell = !echo test
  > parentsshell1 = !echo one
  > parentsshell2 = !echo two
  > escaped1 = !echo 'test$$test'
  > escaped2 = !echo "HGFOO is $$HGFOO"
  > escaped3 = !echo $1 is $$$1
  > escaped4 = !echo \$$0 \$$@
  > exit1 = !sh -c 'exit 1'
  > documented = id
  > documented:doc = an alias for the id command
  > [defaults]
  > mylog = -q
  > lognull = -q
  > log = -v
  > EOF


basic

  $ sl myinit alias


unknown

  $ sl unknown
  unknown command 'bargle'
  (use 'sl help' to get help)
  [255]
  $ sl help unknown
  alias for: bargle
  
  abort: no such help topic: unknown
  (try 'sl help --keyword unknown')
  [255]


ambiguous

  $ sl ambiguous
  unknown command 's'
  (use 'sl help' to get help)
  [255]
  $ sl help ambiguous
  alias for: s
  
  abort: no such help topic: ambiguous
  (try 'sl help --keyword ambiguous')
  [255]


recursive

  $ sl recursive
  unknown command 'recursive'
  (use 'sl help' to get help)
  [255]
  $ sl help recursive
  abort: no such help topic: recursive
  (try 'sl help --keyword recursive')
  [255]


disabled

  $ sl disabled
  unknown command 'extorder'
  (use 'sl help' to get help)
  [255]
  $ sl help disabled
  alias for: extorder
  
  abort: no such help topic: disabled
  (try 'sl help --keyword disabled')
  [255]





no definition

  $ sl nodef
  unknown command 'nodef'
  (use 'sl help' to get help)
  [255]
  $ sl help nodef
  abort: no such help topic: nodef
  (try 'sl help --keyword nodef')
  [255]


no closing quotation

  $ sl noclosing
  unknown command 'noclosing'
  (use 'sl help' to get help)
  [255]
  $ sl help noclosing
  abort: no such help topic: noclosing
  (try 'sl help --keyword noclosing')
  [255]

"--" in alias definition should be preserved

  $ sl --config alias.dash='cat --' -R alias dash -r0
  abort: cwd relative path '-r0' is not under root '$TESTTMP/alias'
  (hint: consider using --cwd to change working directory)
  [255]

invalid options

  $ sl init
  $ sl no--cwd
  abort: option --cwd may not be abbreviated or used in aliases
  [255]
  $ sl help no--cwd
  alias for: status --cwd elsewhere
  
  sl status [OPTION]... [FILE]...
  
  aliases: st
  
  list files with pending changes
  
      Show status of files in the working copy using the following status
      indicators:
  
        M = modified
        A = added
        R = removed
        C = clean
        ! = missing (deleted by a non-sl command, but still tracked)
        ? = not tracked
        I = ignored
          = origin of the previous file (with --copies)
  
      By default, shows files that have been modified, added, removed, deleted,
      or that are unknown (corresponding to the options "-mardu", respectively).
      Files that are unmodified, ignored, or the source of a copy/move operation
      are not listed.
  
      To control the exact statuses that are shown, specify the relevant flags
      (like "-rd" to show only files that are removed or deleted). Additionally,
      specify "-q/--quiet" to hide both unknown and ignored files.
  
      To show the status of specific files, provide a list of files to match. To
      include or exclude files using patterns or filesets, use "-I" or "-X".
  
      If "--rev" is specified and only one revision is given, it is used as the
      base revision. If two revisions are given, the differences between them
      are shown. The "--change" option can also be used as a shortcut to list
      the changed files of a revision from its first parent.
  
      Note:
         "-A/--all", "-c/--clean" can be extremely slow in large repositories
         because they scan all tracked files.
  
      Note:
         'sl status' might appear to disagree with 'sl diff' if permissions have
         changed or a merge has occurred, because the standard diff format does
         not report permission changes and 'sl diff' only reports changes
         relative to one merge parent.
  
      Returns 0 on success.
  
  Options ([+] can be repeated):
  
   -A --all                 show status of all files
   -m --modified            show only modified files
   -a --added               show only added files
   -r --removed             show only removed files
   -d --deleted             show only deleted (but tracked) files
   -c --clean               show only files without changes
   -u --unknown             show only unknown (not tracked) files
   -i --ignored             show only ignored files
   -n --no-status           hide status prefix
   -C --copies              show source of copied files
   -0 --print0              end filenames with NUL, for use with xargs
      --rev REV [+]         show difference from revision
      --change REV          list the changed files of a revision
      --root-relative       show status relative to root
   -I --include PATTERN [+] include files matching the given patterns
   -X --exclude PATTERN [+] exclude files matching the given patterns
  
  (some details hidden, use --verbose to show complete help)
  $ sl no-R
  abort: option -R must appear alone, and --repository may not be abbreviated or used in aliases
  [255]
  $ sl help no-R
  alias for: status -R elsewhere
  
  sl status [OPTION]... [FILE]...
  
  aliases: st
  
  list files with pending changes
  
      Show status of files in the working copy using the following status
      indicators:
  
        M = modified
        A = added
        R = removed
        C = clean
        ! = missing (deleted by a non-sl command, but still tracked)
        ? = not tracked
        I = ignored
          = origin of the previous file (with --copies)
  
      By default, shows files that have been modified, added, removed, deleted,
      or that are unknown (corresponding to the options "-mardu", respectively).
      Files that are unmodified, ignored, or the source of a copy/move operation
      are not listed.
  
      To control the exact statuses that are shown, specify the relevant flags
      (like "-rd" to show only files that are removed or deleted). Additionally,
      specify "-q/--quiet" to hide both unknown and ignored files.
  
      To show the status of specific files, provide a list of files to match. To
      include or exclude files using patterns or filesets, use "-I" or "-X".
  
      If "--rev" is specified and only one revision is given, it is used as the
      base revision. If two revisions are given, the differences between them
      are shown. The "--change" option can also be used as a shortcut to list
      the changed files of a revision from its first parent.
  
      Note:
         "-A/--all", "-c/--clean" can be extremely slow in large repositories
         because they scan all tracked files.
  
      Note:
         'sl status' might appear to disagree with 'sl diff' if permissions have
         changed or a merge has occurred, because the standard diff format does
         not report permission changes and 'sl diff' only reports changes
         relative to one merge parent.
  
      Returns 0 on success.
  
  Options ([+] can be repeated):
  
   -A --all                 show status of all files
   -m --modified            show only modified files
   -a --added               show only added files
   -r --removed             show only removed files
   -d --deleted             show only deleted (but tracked) files
   -c --clean               show only files without changes
   -u --unknown             show only unknown (not tracked) files
   -i --ignored             show only ignored files
   -n --no-status           hide status prefix
   -C --copies              show source of copied files
   -0 --print0              end filenames with NUL, for use with xargs
      --rev REV [+]         show difference from revision
      --change REV          list the changed files of a revision
      --root-relative       show status relative to root
   -I --include PATTERN [+] include files matching the given patterns
   -X --exclude PATTERN [+] exclude files matching the given patterns
  
  (some details hidden, use --verbose to show complete help)
  $ sl no--repo
  abort: option -R must appear alone, and --repository may not be abbreviated or used in aliases
  [255]
  $ sl help no--repo
  alias for: status --repo elsewhere
  
  sl status [OPTION]... [FILE]...
  
  aliases: st
  
  list files with pending changes
  
      Show status of files in the working copy using the following status
      indicators:
  
        M = modified
        A = added
        R = removed
        C = clean
        ! = missing (deleted by a non-sl command, but still tracked)
        ? = not tracked
        I = ignored
          = origin of the previous file (with --copies)
  
      By default, shows files that have been modified, added, removed, deleted,
      or that are unknown (corresponding to the options "-mardu", respectively).
      Files that are unmodified, ignored, or the source of a copy/move operation
      are not listed.
  
      To control the exact statuses that are shown, specify the relevant flags
      (like "-rd" to show only files that are removed or deleted). Additionally,
      specify "-q/--quiet" to hide both unknown and ignored files.
  
      To show the status of specific files, provide a list of files to match. To
      include or exclude files using patterns or filesets, use "-I" or "-X".
  
      If "--rev" is specified and only one revision is given, it is used as the
      base revision. If two revisions are given, the differences between them
      are shown. The "--change" option can also be used as a shortcut to list
      the changed files of a revision from its first parent.
  
      Note:
         "-A/--all", "-c/--clean" can be extremely slow in large repositories
         because they scan all tracked files.
  
      Note:
         'sl status' might appear to disagree with 'sl diff' if permissions have
         changed or a merge has occurred, because the standard diff format does
         not report permission changes and 'sl diff' only reports changes
         relative to one merge parent.
  
      Returns 0 on success.
  
  Options ([+] can be repeated):
  
   -A --all                 show status of all files
   -m --modified            show only modified files
   -a --added               show only added files
   -r --removed             show only removed files
   -d --deleted             show only deleted (but tracked) files
   -c --clean               show only files without changes
   -u --unknown             show only unknown (not tracked) files
   -i --ignored             show only ignored files
   -n --no-status           hide status prefix
   -C --copies              show source of copied files
   -0 --print0              end filenames with NUL, for use with xargs
      --rev REV [+]         show difference from revision
      --change REV          list the changed files of a revision
      --root-relative       show status relative to root
   -I --include PATTERN [+] include files matching the given patterns
   -X --exclude PATTERN [+] exclude files matching the given patterns
  
  (some details hidden, use --verbose to show complete help)
  $ sl no--repository
  abort: option -R must appear alone, and --repository may not be abbreviated or used in aliases
  [255]
  $ sl help no--repository
  alias for: status --repository elsewhere
  
  sl status [OPTION]... [FILE]...
  
  aliases: st
  
  list files with pending changes
  
      Show status of files in the working copy using the following status
      indicators:
  
        M = modified
        A = added
        R = removed
        C = clean
        ! = missing (deleted by a non-sl command, but still tracked)
        ? = not tracked
        I = ignored
          = origin of the previous file (with --copies)
  
      By default, shows files that have been modified, added, removed, deleted,
      or that are unknown (corresponding to the options "-mardu", respectively).
      Files that are unmodified, ignored, or the source of a copy/move operation
      are not listed.
  
      To control the exact statuses that are shown, specify the relevant flags
      (like "-rd" to show only files that are removed or deleted). Additionally,
      specify "-q/--quiet" to hide both unknown and ignored files.
  
      To show the status of specific files, provide a list of files to match. To
      include or exclude files using patterns or filesets, use "-I" or "-X".
  
      If "--rev" is specified and only one revision is given, it is used as the
      base revision. If two revisions are given, the differences between them
      are shown. The "--change" option can also be used as a shortcut to list
      the changed files of a revision from its first parent.
  
      Note:
         "-A/--all", "-c/--clean" can be extremely slow in large repositories
         because they scan all tracked files.
  
      Note:
         'sl status' might appear to disagree with 'sl diff' if permissions have
         changed or a merge has occurred, because the standard diff format does
         not report permission changes and 'sl diff' only reports changes
         relative to one merge parent.
  
      Returns 0 on success.
  
  Options ([+] can be repeated):
  
   -A --all                 show status of all files
   -m --modified            show only modified files
   -a --added               show only added files
   -r --removed             show only removed files
   -d --deleted             show only deleted (but tracked) files
   -c --clean               show only files without changes
   -u --unknown             show only unknown (not tracked) files
   -i --ignored             show only ignored files
   -n --no-status           hide status prefix
   -C --copies              show source of copied files
   -0 --print0              end filenames with NUL, for use with xargs
      --rev REV [+]         show difference from revision
      --change REV          list the changed files of a revision
      --root-relative       show status relative to root
   -I --include PATTERN [+] include files matching the given patterns
   -X --exclude PATTERN [+] exclude files matching the given patterns
  
  (some details hidden, use --verbose to show complete help)
  $ sl no--config
  abort: option --config may not be abbreviated, used in aliases, or used as a value for another option
  [255]
  $ sl no --config alias.no='--repo elsewhere --cwd elsewhere status'
  unknown command '--repo'
  (use 'sl help' to get help)
  [255]
  $ sl no --config alias.no='--repo elsewhere'
  unknown command '--repo'
  (use 'sl help' to get help)
  [255]

optional repository

#if no-outer-repo
  $ sl optionalrepo
  init
#endif
  $ cd alias
  $ cat > .sl/config <<EOF
  > [alias]
  > myinit = init -q
  > EOF
  $ sl optionalrepo
  init -q

no usage

  $ sl nousage
  abort: rollback is dangerous and should not be used
  [255]

  $ echo foo > foo
  $ sl commit -Amfoo
  adding foo

infer repository

  $ cd ..

#if no-outer-repo
  $ sl shortlog alias/foo
  0 e63c23eaa88a | 1970-01-01 00:00 +0000
#endif

  $ cd alias

with opts

  $ sl cleanst
  unknown command 'cleanst'
  (use 'sl help' to get help)
  [255]


with opts and whitespace

  $ sl shortlog
  e63c23eaa88a | 1970-01-01 00:00 +0000

interaction with defaults

  $ sl mylog
  commit:      e63c23eaa88a
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     foo
  
  $ sl lognull
  commit:      000000000000
  user:        
  date:        Thu Jan 01 00:00:00 1970 +0000
  


properly recursive

  $ sl dln
  commit:      0000000000000000000000000000000000000000
  phase:       public
  manifest:    0000000000000000000000000000000000000000
  user:        
  date:        Thu Jan 01 00:00:00 1970 +0000
  extra:       branch=default
  

simple shell aliases

  $ sl blank
  

  $ sl blank foo
  

  $ sl self
  self
  $ sl echoall
  

  $ sl echoall foo
  foo
  $ sl echoall 'test $2' foo
  test $2 foo
  $ sl echoall 'test $@' foo '$@'
  test $@ foo $@
  $ sl echoall 'test "$@"' foo '"$@"'
  test "$@" foo "$@"
  $ sl echo1 foo bar baz
  foo
  $ sl echo2 foo bar baz
  bar
  $ sl echo13 foo bar baz test
  foo baz
  $ sl echo2 foo
  

  $ sl echotokens
  

  $ sl echotokens foo 'bar $1 baz'
  foo
  bar $1 baz
  $ sl echotokens 'test $2' foo
  test $2
  foo
  $ sl echotokens 'test $@' foo '$@'
  test $@
  foo
  $@
  $ sl echotokens 'test "$@"' foo '"$@"'
  test "$@"
  foo
  "$@"
  $ echo bar > bar
  $ sl commit -qA -m bar
  $ sl count .
  1
  $ sl count 'branch(default)'
  2
  $ sl mcount -r '"branch(default)"'
  2

  $ tglog
  @  c0c7cf58edc5 'bar'
  │
  o  e63c23eaa88a 'foo'
  



shadowing

  $ sl i
  unknown command 'i'
  (use 'sl help' to get help)
  [255]
  $ sl id
  c0c7cf58edc5
  $ sl ida
  unknown command 'ida'
  (use 'sl help' to get help)
  [255]
  $ sl idalias
  c0c7cf58edc5
  $ sl idaliasl
  unknown command 'idaliasl'
  (use 'sl help' to get help)
  [255]
  $ sl idaliass
  unknown command 'idaliass'
  (use 'sl help' to get help)
  [255]
  $ sl parentsshell
  unknown command 'parentsshell'
  (use 'sl help' to get help)
  [255]
  $ sl parentsshell1
  one
  $ sl parentsshell2
  two


shell aliases with global options

  $ sl init sub
  $ cd sub
  $ sl count 'branch(default)'
  0
  $ sl -v count 'branch(default)'
  0
  $ sl -R .. count 'branch(default)'
  warning: --repository ignored
  0
  $ sl --cwd .. count 'branch(default)'
  2

global flags after the shell alias name is passed to the shell command, not handled by hg

  $ sl echoall --cwd ..
  abort: option --cwd may not be abbreviated or used in aliases
  [255]


"--" passed to shell alias should be preserved

  $ sl --config alias.printf='!printf "$@"' printf '%s %s %s\n' -- --cwd ..
  -- --cwd ..

repo specific shell aliases

  $ cat >> .sl/config <<EOF
  > [alias]
  > subalias = !echo sub
  > EOF
  $ cat >> ../.sl/config <<EOF
  > [alias]
  > mainalias = !echo main
  > EOF


shell alias defined in current repo

  $ sl subalias
  sub
  $ sl --cwd .. subalias > /dev/null
  unknown command 'subalias'
  (use 'sl help' to get help)
  [255]
  $ sl -R .. subalias > /dev/null
  unknown command 'subalias'
  (use 'sl help' to get help)
  [255]


shell alias defined in other repo

  $ sl mainalias > /dev/null
  unknown command 'mainalias'
  (use 'sl help' to get help)
  [255]
  $ sl -R .. mainalias
  warning: --repository ignored
  main
  $ sl --cwd .. mainalias
  main

typos get useful suggestions
  $ sl --cwd .. manalias
  unknown command 'manalias'
  (use 'sl help' to get help)
  [255]

shell aliases with escaped $ chars

  $ sl escaped1
  test$test
  $ sl escaped2
  HGFOO is BAR
  $ sl escaped3 HGFOO
  HGFOO is BAR
  $ sl escaped4 test
  $0 $@

abbreviated name, which matches against both shell alias and the
command provided extension, should be aborted.

  $ cat >> .sl/config <<EOF
  > [extensions]
  > rebase =
  > EOF
  $ cat >> .sl/config <<'EOF'
  > [alias]
  > rebate = !echo this is rebate $@
  > EOF

  $ sl rebat
  unknown command 'rebat'
  (use 'sl help' to get help)
  [255]
  $ sl rebat --foo-bar
  unknown command 'rebat'
  (use 'sl help' to get help)
  [255]

invalid arguments

  $ sl rt foo
  abort: invalid arguments
  (use '--help' to get help)
  [255]

invalid global arguments for normal commands, aliases, and shell aliases

  $ sl --invalid root
  unknown command '--invalid'
  (use 'sl help' to get help)
  [255]
  $ sl --invalid mylog
  unknown command '--invalid'
  (use 'sl help' to get help)
  [255]
  $ sl --invalid blank
  unknown command '--invalid'
  (use 'sl help' to get help)
  [255]

This should show id:

  $ sl --config alias.log='id' log
  000000000000

This shouldn't:

  $ sl --config alias.log='id' history

  $ cd ../..

return code of command and shell aliases:

  $ sl mycommit -R alias
  nothing changed
  [1]
  $ sl exit1
  [1]

documented aliases

  $ newrepo
  $ sl documented:doc
  unknown command 'documented:doc'
  (use 'sl help' to get help)
  [255]

  $ sl help documented
  [^ ].* (re) (?)
  
  an alias for the id command
  
  sl identify [-nibtB] [-r REV] [SOURCE]
  
  aliases: id
  
  identify the working directory or specified revision
  
      Print a summary identifying the repository state at REV using one or two
      parent hash identifiers, followed by a "+" if the working directory has
      uncommitted changes and a list of bookmarks.
  
      When REV is not given, print a summary of the current state of the
      repository.
  
      Specifying a path to a repository root or Sapling bundle will cause lookup
      to operate on that repository/bundle.
  
      See 'sl log' for generating more information about specific revisions,
      including full hash identifiers.
  
      Returns 0 if successful.
  
  Options:
  
   -r --rev REV   identify the specified revision
   -n --num       show local revision number
   -i --id        show global revision id
   -B --bookmarks show bookmarks
  
  (some details hidden, use --verbose to show complete help)












  $ sl help commands | grep documented
  [1]
