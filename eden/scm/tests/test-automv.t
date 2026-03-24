
#require no-eden

# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# Tests for the automv extension; detect moved files at commit time.

  $ export HGIDENTITY=sl
  $ eagerepo

  $ cat >> $HGRCPATH << 'EOF'
  > [extensions]
  > automv=
  > rebase=
  > EOF
  $ setconfig automv.similarity=75
  $ setconfig commands.update.check=none

# Setup repo

  $ sl init repo
  $ cd repo

# Test automv command for commit

  $ printf 'foo\nbar\nbaz\n' > a.txt
  $ sl add a.txt
  $ sl commit -m 'init repo with a'
  $ sl bookmark -i rev0

# mv/rm/add

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit -m msg
  recording removal of a.txt as rename to b.txt (100% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# mv/rm/add/modif

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit -m msg
  recording removal of a.txt as rename to b.txt (75% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# mv/rm/add/modif

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\nfoo\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit -m msg
  $ sl status --change . -C
  A b.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# mv/rm/add/modif/changethreshold

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\nfoo\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --config 'automv.similarity=60' -m msg
  recording removal of a.txt as rename to b.txt (60% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# mv

  $ mv a.txt b.txt
  $ sl status -C
  ! a.txt
  ? b.txt
  $ sl commit -m msg
  nothing changed (1 missing files, see 'sl status')
  [1]
  $ sl status -C
  ! a.txt
  ? b.txt
  $ sl revert -aqC
  $ rm b.txt

# mv/rm/add/notincommitfiles

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ echo bar > c.txt
  $ sl add c.txt
  $ sl status -C
  A b.txt
  A c.txt
  R a.txt
  $ sl commit c.txt -m msg
  $ sl status --change . -C
  A c.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl rm a.txt
  $ echo bar > c.txt
  $ sl add c.txt
  $ sl commit -m msg
  recording removal of a.txt as rename to b.txt (100% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv/rm/add/--no-automv

  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --no-move-detection -m msg
  $ sl status --change . -C
  A b.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# Test automv command for commit --amend
# mv/rm/add

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend -m amended
  recording removal of a.txt as rename to b.txt (100% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv/rm/add/modif

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend -m amended
  recording removal of a.txt as rename to b.txt (75% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv/rm/add/modif

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\nfoo\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend -m amended
  $ sl status --change . -C
  A b.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv/rm/add/modif/changethreshold

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ printf '\nfoo\n' >> b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend --config 'automv.similarity=60' -m amended
  recording removal of a.txt as rename to b.txt (60% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl status -C
  ! a.txt
  ? b.txt
  $ sl commit --amend -m amended
  $ sl status -C
  ! a.txt
  ? b.txt
  $ sl up -Cr 'min(rev0)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

# mv/rm/add/notincommitfiles

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ echo bar > d.txt
  $ sl add d.txt
  $ sl status -C
  A b.txt
  A d.txt
  R a.txt
  $ sl commit --amend -m amended d.txt
  $ sl status --change . -C
  A c.txt
  A d.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend -m amended
  recording removal of a.txt as rename to b.txt (100% similar)
  $ sl status --change . -C
  A b.txt
    a.txt
  A c.txt
  A d.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 3 files removed, 0 files unresolved

# mv/rm/add/--no-automv

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl add b.txt
  $ sl status -C
  A b.txt
  R a.txt
  $ sl commit --amend -m amended --no-automv
  $ sl status --change . -C
  A b.txt
  A c.txt
  R a.txt
  $ sl up -r 'min(rev0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved

# mv/rm/commit/add/amend

  $ echo c > c.txt
  $ sl add c.txt
  $ sl commit -m 'revision to amend to'
  $ mv a.txt b.txt
  $ sl rm a.txt
  $ sl status -C
  R a.txt
  ? b.txt
  $ sl commit -m 'removed a'
  $ sl add b.txt
  $ sl commit --amend -m amended
  $ sl status --change . -C
  A b.txt
  R a.txt

# error conditions

  $ sl commit -m 'revision to amend to' --config automv.similarity=110
  abort: similarity must be between 0 and 100
  [255]

# max-files setting

  $ newrepo
  $ touch A
  $ sl ci -m A -A A --config automv.similarity=1
  $ mv A B
  $ sl addremove A B
  $ sl ci -m mv --config automv.max-files=0 --config automv.similarity=1
  $ sl status --change . -C
  A B
  R A

# "mv" + "commit --adremove"

  $ newrepo
  $ echo foo > A
  $ sl ci -Aqm A
  $ mv A B
  $ sl ci -Aqm mv
  $ sl status --change . -C
  A B
    A
  R A

# skip added files if copy info already exists

  $ newrepo
  $ mkdir foo
  $ echo aaa > foo/a.txt
  $ echo bbb > foo/b.txt
  $ sl ci -Aqm A
  $ sl mv foo bar
  moving foo/a.txt to bar/a.txt
  moving foo/b.txt to bar/b.txt
  $ sl ci -m mv --config automv.max-files=1
