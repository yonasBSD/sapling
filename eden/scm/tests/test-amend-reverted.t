
#require no-eden


  $ eagerepo

  $ enable amend
  $ setconfig diff.git=1

  $ configure mutation-norecord

Basic amend

  $ sl init repo1
  $ cd repo1
  $ sl debugdrawdag <<'EOS'
  > B
  > |
  > A
  > EOS

  $ sl goto B -q
  $ echo 2 >> B
  $ sl amend
  $ sl log -r . -T '{files}'
  B (no-eol)
  $ sl st

Now revert and amend file B, we should get an empty commit
  $ sl revert -r .^ B
  $ sl amend
  $ sl st
  $ sl log -r . -T '{files}'


Create a commit with a few files, revert a few of them
and then amend them one by one
  $ echo 1 > 1
  $ echo 2 > 2
  $ echo 3 > 3
  $ sl add 1 2 3
  $ sl ci -m '1 2 3'
  $ sl revert -r .^ 1
  $ sl revert -r .^ 2

Now amend a single file
  $ sl st
  R 1
  R 2
  $ sl amend 1
  $ sl st
  R 2
  $ sl log -r . -T '{files}'
  2 3 (no-eol)

Now amend the second file
  $ sl amend 2
  $ sl st
  $ sl log -r . -T '{files}'
  3 (no-eol)

Now rename a file and amend
  $ sl mv 3 33
  $ sl amend
  $ sl st
  $ sl log -r . -T '{files}'
  33 (no-eol)

  $ sl mv 33 333
  $ sl amend 333
  $ sl log -r . -T '{files}'
  33 333 (no-eol)


Create a commit with two files, then change these files in another
commit, then revert two of them and then amend a single one
  $ echo x > x
  $ echo y > y
  $ sl add x y
  $ sl ci -m 'x y'
  $ echo xx > x
  $ echo yy > y
  $ sl ci -m 'xx yy'
  $ sl revert -r .^ x
  $ sl revert -r .^ y
  $ sl amend x
  $ sl st
  M y
  $ sl log -r . -T '{files}'
  y (no-eol)

