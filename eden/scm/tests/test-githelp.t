
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo foo > test_file
  $ mkdir dir
  $ echo foo > dir/file
  $ echo foo > removed_file
  $ echo foo > deleted_file
  $ sl add -q .
  $ sl commit -m 'bar'
  $ sl bookmark both
  $ touch both
  $ touch untracked_file
  $ sl remove removed_file
  $ rm deleted_file

githelp on a single command should succeed
  $ sl githelp -- commit
  sl commit
  $ sl githelp -- git commit
  sl commit

githelp should fail nicely if we don't give it arguments
  $ sl githelp
  abort: missing git command - usage: sl githelp -- <git command>
  [255]
  $ sl githelp -- git
  abort: missing git command - usage: sl githelp -- <git command>
  [255]

githelp on a command with options should succeed
  $ sl githelp -- commit -pm "abc"
  sl commit -m 'abc' -i

githelp on a command with standalone unrecognized option should succeed with warning
  $ sl githelp -- commit -p -v
  ignoring unknown option -v
  sl commit -i

githelp on a command with unrecognized option packed with other options should fail with error
  $ sl githelp -- commit -pv
  abort: unknown option -v packed with other options
  Please try passing the option as it's own flag: -v
  [255]

githelp with a customized footer for invalid commands
  $ sl --config githelp.unknown.footer="This is a custom footer." githelp -- commit -pv
  abort: unknown option -v packed with other options
  Please try passing the option as it's own flag: -v
  [255]

githelp for git rebase --skip
  $ sl githelp -- git rebase --skip
  sl revert --all -r .
  sl rebase --continue

githelp for git rebase --interactive
  $ sl githelp -- git rebase -i master
  note: if you don't need to rebase use 'sl histedit'. It just edits history.
  
  also note: 'sl histedit' will automatically detect your stack, so no second argument is necessary.
  
  sl rebase --interactive -d master

githelp for git commit --amend (sl commit --amend pulls up an editor)
  $ sl githelp -- commit --amend
  sl amend --edit

githelp for git commit --amend --no-edit (sl amend does not pull up an editor)
  $ sl githelp -- commit --amend --no-edit
  sl amend

githelp for git checkout -- . (checking out a directory)
  $ sl githelp -- checkout -- .
  sl revert .


githelp for git checkout "HEAD^" (should still work to pass a rev)
  $ sl githelp -- checkout "HEAD^"
  sl goto .^

githelp checkout: args after -- should be treated as paths no matter what
  $ sl githelp -- checkout -- HEAD
  sl revert HEAD


githelp for git checkout with rev and path
  $ sl githelp -- checkout "HEAD^" -- file.txt
  sl revert -r .^ file.txt


githelp for git with rev and path, without separator
  $ sl githelp -- checkout "HEAD^" file.txt
  sl revert -r .^ file.txt


githelp for checkout with a file as first argument
  $ sl githelp -- checkout test_file
  sl revert test_file


githelp for checkout with a removed file as first argument
  $ sl githelp -- checkout removed_file
  sl revert removed_file


githelp for checkout with a deleted file as first argument
  $ sl githelp -- checkout deleted_file
  sl revert deleted_file


githelp for checkout with a untracked file as first argument
  $ sl githelp -- checkout untracked_file
  sl revert untracked_file


githelp for checkout with a directory as first argument
  $ sl githelp -- checkout dir
  sl revert dir


githelp for checkout when not in repo root
  $ cd dir
  $ sl githelp -- checkout file
  sl revert file

  $ cd ..

githelp for checkout with an argument that is both a file and a revision
  $ sl githelp -- checkout both
  sl goto both

githelp for checkout with the -p option
  $ sl githelp -- git checkout -p xyz
  sl revert -i -r xyz

  $ sl githelp -- git checkout -p xyz -- abc
  sl revert -i -r xyz abc

githelp for checkout with the -f option and a rev
  $ sl githelp -- git checkout -f xyz
  sl goto -C xyz
  $ sl githelp -- git checkout --force xyz
  sl goto -C xyz

githelp for checkout with the -f option without an arg
  $ sl githelp -- git checkout -f
  sl revert --all
  $ sl githelp -- git checkout --force
  sl revert --all

githelp for grep with pattern and path
  $ sl githelp -- grep shrubbery flib/intern/
  sl grep shrubbery flib/intern/

githelp for reset, checking ~ in git becomes ~1 in mercurial
  $ sl githelp -- reset HEAD~
  Sapling has no strict equivalent to `git reset`.
  If you want to remove a commit, use `sl hide -r HASH`.
  If you want to move a bookmark, use `sl book -r HASH NAME`.
  If you want to undo a commit, use `sl uncommit.
  If you want to undo an amend, use `sl unamend.
  $ sl githelp -- reset "HEAD^"
  Sapling has no strict equivalent to `git reset`.
  If you want to remove a commit, use `sl hide -r HASH`.
  If you want to move a bookmark, use `sl book -r HASH NAME`.
  If you want to undo a commit, use `sl uncommit.
  If you want to undo an amend, use `sl unamend.
  $ sl githelp -- reset HEAD~3
  Sapling has no strict equivalent to `git reset`.
  If you want to remove a commit, use `sl hide -r HASH`.
  If you want to move a bookmark, use `sl book -r HASH NAME`.
  If you want to undo a commit, use `sl uncommit.
  If you want to undo an amend, use `sl unamend.

githelp for git show --name-status
  $ sl githelp -- git show --name-status
  sl log --style status -r tip

githelp for git show --pretty=format: --name-status
  $ sl githelp -- git show --pretty=format: --name-status
  sl stat --change tip

githelp for show with no arguments
  $ sl githelp -- show
  sl show

githelp for show with a path
  $ sl githelp -- show test_file
  sl show . test_file

githelp for show with not a path:
  $ sl githelp -- show rev
  sl show rev

githelp for show with many arguments
  $ sl githelp -- show argone argtwo
  sl show argone argtwo
  $ sl githelp -- show test_file argone argtwo
  sl show . test_file argone argtwo

githelp for show with --unified options
  $ sl githelp -- show --unified=10
  sl show --config diff.unified=10
  $ sl githelp -- show -U100
  sl show --config diff.unified=100

githelp for show with a path and --unified
  $ sl githelp -- show -U20 test_file
  sl show . test_file --config diff.unified=20

githelp for stash drop without name
  $ sl githelp -- git stash drop
  sl shelve -d <shelve name>

githelp for stash drop with name
  $ sl githelp -- git stash drop xyz
  sl shelve -d xyz

githelp for whatchanged should show deprecated message
  $ sl githelp -- whatchanged -p
  This command has been deprecated in the git project, thus isn't supported by this tool.
  

githelp for git branch -m renaming
  $ sl githelp -- git branch -m old new
  sl bookmark -m old new

When the old name is omitted, git branch -m new renames the current branch.
  $ sl githelp -- git branch -m new
  sl bookmark -m `sl log -T"{activebookmark}" -r .` new

Branch deletion in git strips commits
  $ sl githelp -- git branch -d
  sl hide -B
  $ sl githelp -- git branch -d feature
  sl hide -B feature
  $ sl githelp -- git branch --delete experiment1 experiment2
  sl hide -B experiment1 -B experiment2

githelp for reuse message using the shorthand
  $ sl githelp -- git commit -C deadbeef
  sl commit -M deadbeef

githelp for reuse message using the the long version
  $ sl githelp -- git commit --reuse-message deadbeef
  sl commit -M deadbeef

githelp for apply with no options
  $ sl githelp -- apply
  sl import --no-commit

githelp for apply with directory strip custom
  $ sl githelp -- apply -p 5
  sl import --no-commit -p 5

git merge-base
  $ sl githelp -- git merge-base --is-ancestor
  ignoring unknown option --is-ancestor
  NOTE: ancestors() is part of the revset language.
  Learn more about revsets with 'sl help revsets'
  
  sl log -T '{node}\n' -r 'ancestor(A,B)'

githelp for git blame (tweakdefaults disabled)
  $ sl githelp -- git blame
  sl annotate -pudl

githelp for git blame (tweakdefaults enabled)
  $ sl --config extensions.tweakdefaults= githelp -- git blame
  sl annotate -pudl

githelp for git clean (with path)
  $ sl githelp -- git clean -f .
  sl clean --dirs --files .

githelp for git clean (with -d and no path)
  $ sl githelp -- git clean -fd
  sl clean --dirs --files

githelp for git clean (with -d and path)
  $ sl githelp -- git clean -fd .
  sl clean --dirs --files .

githelp for git clean (with -dx)
  $ sl githelp -- git clean -fdx
  sl clean --dirs --files --ignored

githelp for git clean (with -x and path)
  $ sl githelp -- git clean -fx .
  sl clean --dirs --files --ignored .

githelp for git clean (with -x)
  $ sl githelp -- git clean -fx
  sl clean --ignored
