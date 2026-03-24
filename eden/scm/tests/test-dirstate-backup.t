
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Set up

  $ sl init repo
  $ cd repo

Try to import an empty patch

  $ sl import --no-commit - <<EOF
  > EOF
  applying patch from stdin
  abort: stdin: no diffs found
  [255]

No dirstate backups are left behind

  $ echo .sl/dirstate*
  .sl/dirstate

