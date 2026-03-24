
#require no-eden

  $ export HGIDENTITY=sl
  $ enable amend rebase
  $ newrepo

  $ touch base
  $ sl commit -Aqm base

Create a file, and then move it to another directory in the next commit.
  $ mkdir dir1
  $ echo a > dir1/file1
  $ sl commit -Am "original commit"
  adding dir1/file1
  $ mkdir dir2
  $ sl mv dir1/file1 dir2/
  $ sl commit -m "move directory"

Amend the bottom commit to rename the file
  $ sl prev -q
  [54bfd3] original commit
  $ sl mv dir1/file1 dir1/file2
  $ sl amend
  hint[amend-restack]: descendants of 54bfd3f39556 are left behind - use 'sl restack' to rebase them
  hint[hint-ack]: use 'sl hint --ack amend-restack' to silence these hints

Rebase with fastcopytrace hits conflicts as it doesn't detect the dir rename.
  $ sl rebase --restack
  rebasing 75532295d2d9 "move directory"
  local [dest] changed dir1/file2 which other [source] deleted (as dir1/file1)
  use (c)hanged version, (d)elete, or leave (u)nresolved? u
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

  $ sl rebase --abort
  rebase aborted

# dagcopytrace does not support directory move
  $ sl rebase --restack --config copytrace.dagcopytrace=True
  rebasing 75532295d2d9 "move directory"
  local [dest] changed dir1/file2 which other [source] deleted (as dir1/file1)
  use (c)hanged version, (d)elete, or leave (u)nresolved? u
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
