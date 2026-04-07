
#require no-eden

# coding=utf-8

# Copyright (c) Meta Platforms, Inc. and affiliates.
# Copyright (c) Mercurial Contributors.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

  $ eagerepo

# Prepare test functions

    import os
    import generateworkingcopystates
    
    def dircontent():
        # generate a simple text view of the directory for easy comparison
        files = os.listdir(".")
        files.sort()
        output = []
        for filename in files:
            if os.path.isdir(filename):
                continue
            content = open(filename).read()
            output.append("%-6s %s" % (content.strip(), filename))
        return "\n".join(output)

# init 

  $ sl init repo
  $ cd repo
  $ echo 123 > a
  $ echo 123 > c
  $ echo 123 > e
  $ sl add a c e
  $ sl commit -m first a c e

# nothing changed

  $ sl revert
  abort: no files or directories specified
  (use --all to revert all files)
  [255]
  $ sl revert --all

# Introduce some changes and revert them
# --------------------------------------

  $ echo 123 > b

  $ sl status
  ? b
  $ echo 12 > c

  $ sl status
  M c
  ? b
  $ sl add b

  $ sl status
  M c
  A b
  $ sl rm a

  $ sl status
  M c
  A b
  R a

# revert removal of a file

  $ sl revert a
  $ sl status
  M c
  A b

# revert addition of a file

  $ sl revert b
  $ sl status
  M c
  ? b

# revert modification of a file (--no-backup)

  $ sl revert --no-backup c
  $ sl status
  ? b

# revert deletion (! status) of a added file
# ------------------------------------------

  $ sl add b

  $ sl status b
  A b
  $ rm b
  $ sl status b
  ! b
  $ sl revert -v b
  forgetting b
  $ sl status b
  b: $ENOENT$

  $ ls
  a
  c
  e

# Test creation of backup (.orig) files
# -------------------------------------

  $ echo z > e
  $ sl revert --all -v
  saving current version of e as e.orig
  reverting e

# Test creation of backup (.orig) file in configured file location
# ----------------------------------------------------------------

  $ echo z > e
  $ sl revert --all -v --config 'ui.origbackuppath=.hg/origbackups'
  creating directory: $TESTTMP/repo/.sl/origbackups
  saving current version of e as $TESTTMP/repo/.sl/origbackups/e
  reverting e
  $ rm -rf .sl/origbackups

# revert on clean file (no change)
# --------------------------------

  $ sl revert a
  no changes needed to a

  $ sl revert -q a

# revert on an untracked file
# ---------------------------

  $ echo q > q
  $ sl revert q
  file not managed: q
  $ rm q

# revert on file that does not exists
# -----------------------------------

  $ sl revert notfound
  notfound: no such file in rev 334a9e57682c
  $ touch d
  $ sl add d
  $ sl rm a
  $ sl commit -m second
  $ echo z > z
  $ sl add z
  $ sl st
  A z
  ? e.orig

# revert to another revision (--rev)
# ----------------------------------

  $ sl revert --all -r 'desc(first)'
  adding a
  removing d
  forgetting z

# revert explicitly to parent (--rev)
# -----------------------------------

  $ sl revert --all -rtip
  forgetting a
  undeleting d
  $ rm a *.orig

# revert to another revision (--rev) and exact match
# --------------------------------------------------
# exact match are more silent

  $ sl revert -r 'desc(first)' a
  $ sl st a
  A a
  $ sl rm d
  $ sl st d
  R d

# should keep d removed

  $ sl revert -r 'desc(first)' d
  no changes needed to d
  $ sl st d
  R d

  $ sl goto -C .
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

#if execbit
  $ chmod +x c
  $ sl revert --all
  reverting c

  $ test -x c
  [1]

  $ chmod +x c
  $ sl commit -m exe

  $ chmod -x c
  $ sl revert --all
  reverting c

  $ test -x c
  $ echo executable
  executable
#endif

# Test that files reverted to other than the parent are treated as
# "modified", even if none of mode, size and timestamp of it isn't
# changed on the filesystem (see also issue4583).

  $ echo 321 > e
  $ sl diff --git
  diff --git a/e b/e
  --- a/e
  +++ b/e
  @@ -1,1 +1,1 @@
  -123
  +321
  $ sl commit -m 'ambiguity from size'

  $ cat e
  321
  $ touch -t 200001010000 e
  $ sl debugrebuildstate

  $ cat >> .sl/config << 'EOF'
  > [fakedirstatewritetime]
  > # emulate invoking dirstate.write() via repo.status()
  > # at 2000-01-01 00:00
  > fakenow = 2000-01-01 00:00:00
  > 
  > [extensions]
  > fakedirstatewritetime = $TESTDIR/fakedirstatewritetime.py
  > EOF
  $ sl revert -r 'desc(first)' e
  $ cat >> .sl/config << 'EOF'
  > [extensions]
  > fakedirstatewritetime = !
  > EOF

  $ cat e
  123
  $ touch -t 200001010000 e
  $ sl status -A e
  M e

  $ cd ..

# Issue241: update and revert produces inconsistent repositories
# --------------------------------------------------------------

  $ sl init a
  $ cd a
  $ echo a >> a
  $ sl commit -A -d '1 0' -m issue241-first
  adding a
  $ echo a >> a
  $ sl commit -d '2 0' -m issue241-second
  $ sl goto 'desc("issue241-first")'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ mkdir b
  $ echo b > b/b

# call `sl revert` with no file specified
# ---------------------------------------

  $ sl revert -rtip
  abort: no files or directories specified
  (use --all to revert all files, or 'sl goto e655737eacaa' to update)
  [255]

# call `sl revert` with -I
# ---------------------------

  $ echo a >> a
  $ sl revert -I a
  reverting a

# call `sl revert` with -X
# ---------------------------

  $ echo a >> a
  $ sl revert -X d
  reverting a

# call `sl revert` with --all
# ---------------------------

  $ sl revert --all -rtip
  reverting a
  $ rm 'a.orig'

# Issue332: confusing message when reverting directory
# ----------------------------------------------------

  $ sl ci -A -m b
  adding b/b
  $ echo foobar > b/b
  $ mkdir newdir
  $ echo foo > newdir/newfile
  $ sl add newdir/newfile
  $ sl revert b newdir
  reverting b/b
  forgetting newdir/newfile
  $ echo foobar > b/b
  $ sl revert .
  reverting b/b

# reverting a rename target should revert the source
# --------------------------------------------------

  $ sl mv a newa
  $ sl revert newa
  $ sl st a newa
  ? newa

# Also true for move overwriting an existing file

  $ sl mv --force a b/b
  $ sl revert b/b
  $ sl status a b/b

  $ cd ..

  $ sl init ignored
  $ cd ignored
  $ echo ignored > .gitignore
  $ echo ignoreddir >> .gitignore
  $ echo removed >> .gitignore

  $ mkdir ignoreddir
  $ touch ignoreddir/file
  $ touch ignoreddir/removed
  $ touch ignored
  $ touch removed

# 4 ignored files (we will add/commit everything)

  $ sl st -A -X .gitignore
  I ignored
  I ignoreddir/file
  I ignoreddir/removed
  I removed
  $ sl ci -qAm 'add files' ignored ignoreddir/file ignoreddir/removed removed

  $ echo >> ignored
  $ echo >> ignoreddir/file
  $ sl rm removed ignoreddir/removed

# should revert ignored* and undelete *removed
# --------------------------------------------

  $ sl revert -a --no-backup
  reverting ignored
  reverting ignoreddir/file
  undeleting ignoreddir/removed
  undeleting removed
  $ sl st -mardi

  $ sl up -qC .
  $ echo >> ignored
  $ sl rm removed

# should silently revert the named files
# --------------------------------------

  $ sl revert --no-backup ignored removed
  $ sl st -mardi

# Reverting copy (issue3920)
# --------------------------
# someone set up us the copies

  $ rm .gitignore
  $ sl goto -C .
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl mv ignored allyour
  $ sl copy removed base
  $ sl commit -m rename

# copies and renames, you have no chance to survive make your time (issue3920)

  $ sl goto '.^'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl revert -rtip -a
  adding allyour
  adding base
  removing ignored
  $ sl status -C
  A allyour
    ignored
  A base
    removed
  R ignored

# Test revert of a file added by one side of the merge
# ====================================================
# remove any pending change

  $ sl revert --all
  forgetting allyour
  forgetting base
  undeleting ignored
  $ sl purge --all

# Adds a new commit

  $ echo foo > newadd
  $ sl add newadd
  $ sl commit -m 'other adds'

# merge it with the other head

  $ sl merge
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl summary
  parent: 68b989552c4a 
   other adds
  parent: 2b80f4f4fe72 
   rename
  commit: 2 modified, 1 renamed, 1 copied (merge)
  phases: 3 draft

# clarifies who added what

  $ sl status
  M allyour
  M base
  R ignored
  $ sl status --change 'p1()'
  A newadd
  $ sl status --change 'p2()'
  A allyour
  A base
  R ignored

# revert file added by p1() to p1() state
# -----------------------------------------

  $ sl revert -r 'p1()' 'glob:newad?'
  $ sl status
  M allyour
  M base
  R ignored

# revert file added by p1() to p2() state
# ------------------------------------------

  $ sl revert -r 'p2()' 'glob:newad?'
  removing newadd
  $ sl status
  M allyour
  M base
  R ignored
  R newadd

# revert file added by p2() to p2() state
# ------------------------------------------

  $ sl revert -r 'p2()' 'glob:allyou?'
  $ sl status
  M allyour
  M base
  R ignored
  R newadd

# revert file added by p2() to p1() state
# ------------------------------------------

  $ sl revert -r 'p1()' 'glob:allyou?'
  removing allyour
  $ sl status
  M base
  R allyour
  R newadd

# Systematic behavior validation of most possible cases
# =====================================================

# This section tests most of the possible combinations of revision states and
# working directory states. The number of possible cases is significant but they
# but they all have a slightly different handling. So this section commits to
# and testing all of them to allow safe refactoring of the revert code.

# A python script is used to generate a file history for each combination of
# states, on one side the content (or lack thereof) in two revisions, and
# on the other side, the content and "tracked-ness" of the working directory. The
# three states generated are:

# - a "base" revision
# - a "parent" revision
# - the working directory (based on "parent")

# The files generated have names of the form:

#  <rev1-content>_<rev2-content>_<working-copy-content>-<tracked-ness>

# All known states are not tested yet. See inline documentation for details.
# Special cases from merge and rename are not tested by this section.

# Write the python script to disk
# -------------------------------

# check list of planned files

  >>> print(generateworkingcopystates.main("filelist", 2))
  content1_content1_content1-tracked
  content1_content1_content1-untracked
  content1_content1_content3-tracked
  content1_content1_content3-untracked
  content1_content1_missing-tracked
  content1_content1_missing-untracked
  content1_content2_content1-tracked
  content1_content2_content1-untracked
  content1_content2_content2-tracked
  content1_content2_content2-untracked
  content1_content2_content3-tracked
  content1_content2_content3-untracked
  content1_content2_missing-tracked
  content1_content2_missing-untracked
  content1_missing_content1-tracked
  content1_missing_content1-untracked
  content1_missing_content3-tracked
  content1_missing_content3-untracked
  content1_missing_missing-tracked
  content1_missing_missing-untracked
  missing_content2_content2-tracked
  missing_content2_content2-untracked
  missing_content2_content3-tracked
  missing_content2_content3-untracked
  missing_content2_missing-tracked
  missing_content2_missing-untracked
  missing_missing_content3-tracked
  missing_missing_content3-untracked
  missing_missing_missing-tracked
  missing_missing_missing-untracked


# Script to make a simple text version of the content
# ---------------------------------------------------
# Generate appropriate repo state
# -------------------------------

  $ sl init revert-ref
  $ cd revert-ref

# Generate base changeset

  >>> generateworkingcopystates.main("state", 2, 1)

  $ sl addremove --similarity 0
  adding content1_content1_content1-tracked
  adding content1_content1_content1-untracked
  adding content1_content1_content3-tracked
  adding content1_content1_content3-untracked
  adding content1_content1_missing-tracked
  adding content1_content1_missing-untracked
  adding content1_content2_content1-tracked
  adding content1_content2_content1-untracked
  adding content1_content2_content2-tracked
  adding content1_content2_content2-untracked
  adding content1_content2_content3-tracked
  adding content1_content2_content3-untracked
  adding content1_content2_missing-tracked
  adding content1_content2_missing-untracked
  adding content1_missing_content1-tracked
  adding content1_missing_content1-untracked
  adding content1_missing_content3-tracked
  adding content1_missing_content3-untracked
  adding content1_missing_missing-tracked
  adding content1_missing_missing-untracked
  $ sl status
  A content1_content1_content1-tracked
  A content1_content1_content1-untracked
  A content1_content1_content3-tracked
  A content1_content1_content3-untracked
  A content1_content1_missing-tracked
  A content1_content1_missing-untracked
  A content1_content2_content1-tracked
  A content1_content2_content1-untracked
  A content1_content2_content2-tracked
  A content1_content2_content2-untracked
  A content1_content2_content3-tracked
  A content1_content2_content3-untracked
  A content1_content2_missing-tracked
  A content1_content2_missing-untracked
  A content1_missing_content1-tracked
  A content1_missing_content1-untracked
  A content1_missing_content3-tracked
  A content1_missing_content3-untracked
  A content1_missing_missing-tracked
  A content1_missing_missing-untracked
  $ sl commit -m base

# (create a simple text version of the content)

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content1 content1_content1_content3-untracked
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content1 content1_content2_content1-tracked
  content1 content1_content2_content1-untracked
  content1 content1_content2_content2-tracked
  content1 content1_content2_content2-untracked
  content1 content1_content2_content3-tracked
  content1 content1_content2_content3-untracked
  content1 content1_content2_missing-tracked
  content1 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content1 content1_missing_content3-tracked
  content1 content1_missing_content3-untracked
  content1 content1_missing_missing-tracked
  content1 content1_missing_missing-untracked


# Create parent changeset

  >>> generateworkingcopystates.main("state", 2, 2)

  $ sl addremove --similarity 0
  removing content1_missing_content1-tracked
  removing content1_missing_content1-untracked
  removing content1_missing_content3-tracked
  removing content1_missing_content3-untracked
  removing content1_missing_missing-tracked
  removing content1_missing_missing-untracked
  adding missing_content2_content2-tracked
  adding missing_content2_content2-untracked
  adding missing_content2_content3-tracked
  adding missing_content2_content3-untracked
  adding missing_content2_missing-tracked
  adding missing_content2_missing-untracked
  $ sl status
  M content1_content2_content1-tracked
  M content1_content2_content1-untracked
  M content1_content2_content2-tracked
  M content1_content2_content2-untracked
  M content1_content2_content3-tracked
  M content1_content2_content3-untracked
  M content1_content2_missing-tracked
  M content1_content2_missing-untracked
  A missing_content2_content2-tracked
  A missing_content2_content2-untracked
  A missing_content2_content3-tracked
  A missing_content2_content3-untracked
  A missing_content2_missing-tracked
  A missing_content2_missing-untracked
  R content1_missing_content1-tracked
  R content1_missing_content1-untracked
  R content1_missing_content3-tracked
  R content1_missing_content3-untracked
  R content1_missing_missing-tracked
  R content1_missing_missing-untracked
  $ sl commit -m parent

# (create a simple text version of the content)

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content1 content1_content1_content3-untracked
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content2 content1_content2_content1-untracked
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content2 content1_content2_content3-untracked
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content2 missing_content2_content3-untracked
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked


# Setup working directory

  >>> generateworkingcopystates.main("state", 2, "wc")

  $ sl addremove --similarity 0
  adding content1_missing_content1-tracked
  adding content1_missing_content1-untracked
  adding content1_missing_content3-tracked
  adding content1_missing_content3-untracked
  adding content1_missing_missing-tracked
  adding content1_missing_missing-untracked
  adding missing_missing_content3-tracked
  adding missing_missing_content3-untracked
  adding missing_missing_missing-tracked
  adding missing_missing_missing-untracked
  $ sl forget *_*_*-untracked
  $ rm *_*_missing-*
  $ sl status
  M content1_content1_content3-tracked
  M content1_content2_content1-tracked
  M content1_content2_content3-tracked
  M missing_content2_content3-tracked
  A content1_missing_content1-tracked
  A content1_missing_content3-tracked
  A missing_missing_content3-tracked
  R content1_content1_content1-untracked
  R content1_content1_content3-untracked
  R content1_content1_missing-untracked
  R content1_content2_content1-untracked
  R content1_content2_content2-untracked
  R content1_content2_content3-untracked
  R content1_content2_missing-untracked
  R missing_content2_content2-untracked
  R missing_content2_content3-untracked
  R missing_content2_missing-untracked
  ! content1_content1_missing-tracked
  ! content1_content2_missing-tracked
  ! content1_missing_missing-tracked
  ! missing_content2_missing-tracked
  ! missing_missing_missing-tracked
  ? content1_missing_content1-untracked
  ? content1_missing_content3-untracked
  ? missing_missing_content3-untracked

  $ sl status --rev 'desc("base")'
  M content1_content1_content3-tracked
  M content1_content2_content2-tracked
  M content1_content2_content3-tracked
  M content1_missing_content3-tracked
  A missing_content2_content2-tracked
  A missing_content2_content3-tracked
  A missing_missing_content3-tracked
  R content1_content1_content1-untracked
  R content1_content1_content3-untracked
  R content1_content1_missing-untracked
  R content1_content2_content1-untracked
  R content1_content2_content2-untracked
  R content1_content2_content3-untracked
  R content1_content2_missing-untracked
  R content1_missing_content1-untracked
  R content1_missing_content3-untracked
  R content1_missing_missing-untracked
  ! content1_content1_missing-tracked
  ! content1_content2_missing-tracked
  ! content1_missing_missing-tracked
  ! missing_content2_missing-tracked
  ! missing_missing_missing-tracked
  ? missing_missing_content3-untracked

# (create a simple text version of the content)

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content3 content1_content1_content3-tracked
  content3 content1_content1_content3-untracked
  content1 content1_content2_content1-tracked
  content1 content1_content2_content1-untracked
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content3 content1_content2_content3-tracked
  content3 content1_content2_content3-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content3 missing_content2_content3-tracked
  content3 missing_content2_content3-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert --all to parent content
# -----------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-parent-all
  $ cd revert-parent-all

# check revert output

  $ sl revert --all
  undeleting content1_content1_content1-untracked
  reverting content1_content1_content3-tracked
  undeleting content1_content1_content3-untracked
  reverting content1_content1_missing-tracked
  undeleting content1_content1_missing-untracked
  reverting content1_content2_content1-tracked
  undeleting content1_content2_content1-untracked
  undeleting content1_content2_content2-untracked
  reverting content1_content2_content3-tracked
  undeleting content1_content2_content3-untracked
  reverting content1_content2_missing-tracked
  undeleting content1_content2_missing-untracked
  forgetting content1_missing_content1-tracked
  forgetting content1_missing_content3-tracked
  forgetting content1_missing_missing-tracked
  undeleting missing_content2_content2-untracked
  reverting missing_content2_content3-tracked
  undeleting missing_content2_content3-untracked
  reverting missing_content2_missing-tracked
  undeleting missing_content2_missing-untracked
  forgetting missing_missing_content3-tracked
  forgetting missing_missing_missing-tracked

# Compare resulting directory with revert target.

# The diff is filtered to include change only. The only difference should be
# additional `.orig` backup file when applicable.

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content1 content1_content2_content1-tracked.orig
  content2 content1_content2_content1-untracked
  content1 content1_content2_content1-untracked.orig
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content2 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content3 missing_content2_content3-tracked.orig
  content2 missing_content2_content3-untracked
  content3 missing_content2_content3-untracked.orig
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert --all to "base" content
# -----------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-base-all
  $ cd revert-base-all

# check revert output

  $ sl revert --all --rev 'desc(base)'
  undeleting content1_content1_content1-untracked
  reverting content1_content1_content3-tracked
  undeleting content1_content1_content3-untracked
  reverting content1_content1_missing-tracked
  undeleting content1_content1_missing-untracked
  undeleting content1_content2_content1-untracked
  reverting content1_content2_content2-tracked
  undeleting content1_content2_content2-untracked
  reverting content1_content2_content3-tracked
  undeleting content1_content2_content3-untracked
  reverting content1_content2_missing-tracked
  undeleting content1_content2_missing-untracked
  adding content1_missing_content1-untracked
  reverting content1_missing_content3-tracked
  adding content1_missing_content3-untracked
  reverting content1_missing_missing-tracked
  adding content1_missing_missing-untracked
  removing missing_content2_content2-tracked
  removing missing_content2_content3-tracked
  removing missing_content2_missing-tracked
  forgetting missing_missing_content3-tracked
  forgetting missing_missing_missing-tracked

# Compare resulting directory with revert target.

# The diff is filtered to include change only. The only difference should be
# additional `.orig` backup file when applicable.

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content1 content1_content2_content1-tracked
  content1 content1_content2_content1-untracked
  content1 content1_content2_content2-tracked
  content1 content1_content2_content2-untracked
  content2 content1_content2_content2-untracked.orig
  content1 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content1 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content1 content1_content2_missing-tracked
  content1 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content1 content1_missing_content3-tracked
  content3 content1_missing_content3-tracked.orig
  content1 content1_missing_content3-untracked
  content3 content1_missing_content3-untracked.orig
  content1 content1_missing_missing-tracked
  content1 content1_missing_missing-untracked
  content2 missing_content2_content2-untracked
  content3 missing_content2_content3-tracked.orig
  content3 missing_content2_content3-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert to parent content with explicit file name
# -----------------------------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-parent-explicit
  $ cd revert-parent-explicit

# revert all files individually and check the output
# (output is expected to be different than in the --all case)

  >>> def revertoutput():
  ...     files = generateworkingcopystates.main("filelist", 2)
  ...     output = []
  ...     for myfile in files.split("\n"):
  ...         output.append("### revert for: {}".format(myfile))
  ...         output.append(sheval("sl revert {}".format(myfile)).rstrip() or ".")
  ...     print("\n".join(output))

  >>> revertoutput()
  ### revert for: content1_content1_content1-tracked
  no changes needed to content1_content1_content1-tracked
  ### revert for: content1_content1_content1-untracked
  .
  ### revert for: content1_content1_content3-tracked
  .
  ### revert for: content1_content1_content3-untracked
  .
  ### revert for: content1_content1_missing-tracked
  .
  ### revert for: content1_content1_missing-untracked
  .
  ### revert for: content1_content2_content1-tracked
  .
  ### revert for: content1_content2_content1-untracked
  .
  ### revert for: content1_content2_content2-tracked
  no changes needed to content1_content2_content2-tracked
  ### revert for: content1_content2_content2-untracked
  .
  ### revert for: content1_content2_content3-tracked
  .
  ### revert for: content1_content2_content3-untracked
  .
  ### revert for: content1_content2_missing-tracked
  .
  ### revert for: content1_content2_missing-untracked
  .
  ### revert for: content1_missing_content1-tracked
  .
  ### revert for: content1_missing_content1-untracked
  file not managed: content1_missing_content1-untracked
  ### revert for: content1_missing_content3-tracked
  .
  ### revert for: content1_missing_content3-untracked
  file not managed: content1_missing_content3-untracked
  ### revert for: content1_missing_missing-tracked
  .
  ### revert for: content1_missing_missing-untracked
  content1_missing_missing-untracked: no such file in rev cbcb7147d2a0
  ### revert for: missing_content2_content2-tracked
  no changes needed to missing_content2_content2-tracked
  ### revert for: missing_content2_content2-untracked
  .
  ### revert for: missing_content2_content3-tracked
  .
  ### revert for: missing_content2_content3-untracked
  .
  ### revert for: missing_content2_missing-tracked
  .
  ### revert for: missing_content2_missing-untracked
  .
  ### revert for: missing_missing_content3-tracked
  .
  ### revert for: missing_missing_content3-untracked
  file not managed: missing_missing_content3-untracked
  ### revert for: missing_missing_missing-tracked
  .
  ### revert for: missing_missing_missing-untracked
  missing_missing_missing-untracked: no such file in rev cbcb7147d2a0

# check resulting directory against the --all run
# (There should be no difference)

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content1 content1_content2_content1-tracked.orig
  content2 content1_content2_content1-untracked
  content1 content1_content2_content1-untracked.orig
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content2 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content3 missing_content2_content3-tracked.orig
  content2 missing_content2_content3-untracked
  content3 missing_content2_content3-untracked.orig
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert to "base" content with explicit file name
# -----------------------------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-base-explicit
  $ cd revert-base-explicit

# revert all files individually and check the output
# (output is expected to be different than in the --all case)


  >>> revertoutput()
  ### revert for: content1_content1_content1-tracked
  no changes needed to content1_content1_content1-tracked
  ### revert for: content1_content1_content1-untracked
  .
  ### revert for: content1_content1_content3-tracked
  .
  ### revert for: content1_content1_content3-untracked
  .
  ### revert for: content1_content1_missing-tracked
  .
  ### revert for: content1_content1_missing-untracked
  .
  ### revert for: content1_content2_content1-tracked
  .
  ### revert for: content1_content2_content1-untracked
  .
  ### revert for: content1_content2_content2-tracked
  no changes needed to content1_content2_content2-tracked
  ### revert for: content1_content2_content2-untracked
  .
  ### revert for: content1_content2_content3-tracked
  .
  ### revert for: content1_content2_content3-untracked
  .
  ### revert for: content1_content2_missing-tracked
  .
  ### revert for: content1_content2_missing-untracked
  .
  ### revert for: content1_missing_content1-tracked
  .
  ### revert for: content1_missing_content1-untracked
  file not managed: content1_missing_content1-untracked
  ### revert for: content1_missing_content3-tracked
  .
  ### revert for: content1_missing_content3-untracked
  file not managed: content1_missing_content3-untracked
  ### revert for: content1_missing_missing-tracked
  .
  ### revert for: content1_missing_missing-untracked
  content1_missing_missing-untracked: no such file in rev cbcb7147d2a0
  ### revert for: missing_content2_content2-tracked
  no changes needed to missing_content2_content2-tracked
  ### revert for: missing_content2_content2-untracked
  .
  ### revert for: missing_content2_content3-tracked
  .
  ### revert for: missing_content2_content3-untracked
  .
  ### revert for: missing_content2_missing-tracked
  .
  ### revert for: missing_content2_missing-untracked
  .
  ### revert for: missing_missing_content3-tracked
  .
  ### revert for: missing_missing_content3-untracked
  file not managed: missing_missing_content3-untracked
  ### revert for: missing_missing_missing-tracked
  .
  ### revert for: missing_missing_missing-untracked
  missing_missing_missing-untracked: no such file in rev cbcb7147d2a0


# check resulting directory against the --all run
# (There should be no difference)

  >>> print(dircontent())
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content1 content1_content2_content1-tracked.orig
  content2 content1_content2_content1-untracked
  content1 content1_content2_content1-untracked.orig
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content2 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content3 missing_content2_content3-tracked.orig
  content2 missing_content2_content3-untracked
  content3 missing_content2_content3-untracked.orig
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert to parent content with explicit file name but ignored files
# -----------------------------------------------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-parent-explicit-ignored
  $ cd revert-parent-explicit-ignored
  $ echo * > .gitignore

# revert all files individually and check the output
# (output is expected to be different than in the --all case)

  >>> revertoutput()
  ### revert for: content1_content1_content1-tracked
  no changes needed to content1_content1_content1-tracked
  ### revert for: content1_content1_content1-untracked
  .
  ### revert for: content1_content1_content3-tracked
  .
  ### revert for: content1_content1_content3-untracked
  .
  ### revert for: content1_content1_missing-tracked
  .
  ### revert for: content1_content1_missing-untracked
  .
  ### revert for: content1_content2_content1-tracked
  .
  ### revert for: content1_content2_content1-untracked
  .
  ### revert for: content1_content2_content2-tracked
  no changes needed to content1_content2_content2-tracked
  ### revert for: content1_content2_content2-untracked
  .
  ### revert for: content1_content2_content3-tracked
  .
  ### revert for: content1_content2_content3-untracked
  .
  ### revert for: content1_content2_missing-tracked
  .
  ### revert for: content1_content2_missing-untracked
  .
  ### revert for: content1_missing_content1-tracked
  .
  ### revert for: content1_missing_content1-untracked
  file not managed: content1_missing_content1-untracked
  ### revert for: content1_missing_content3-tracked
  .
  ### revert for: content1_missing_content3-untracked
  file not managed: content1_missing_content3-untracked
  ### revert for: content1_missing_missing-tracked
  .
  ### revert for: content1_missing_missing-untracked
  content1_missing_missing-untracked: no such file in rev cbcb7147d2a0
  ### revert for: missing_content2_content2-tracked
  no changes needed to missing_content2_content2-tracked
  ### revert for: missing_content2_content2-untracked
  .
  ### revert for: missing_content2_content3-tracked
  .
  ### revert for: missing_content2_content3-untracked
  .
  ### revert for: missing_content2_missing-tracked
  .
  ### revert for: missing_content2_missing-untracked
  .
  ### revert for: missing_missing_content3-tracked
  .
  ### revert for: missing_missing_content3-untracked
  file not managed: missing_missing_content3-untracked
  ### revert for: missing_missing_missing-tracked
  .
  ### revert for: missing_missing_missing-untracked
  missing_missing_missing-untracked: no such file in rev cbcb7147d2a0


# check resulting directory against the --all run

  >>> print(dircontent())
  content1_content1_content1-tracked content1_content1_content1-untracked content1_content1_content3-tracked content1_content1_content3-untracked content1_content2_content1-tracked content1_content2_content1-untracked content1_content2_content2-tracked content1_content2_content2-untracked content1_content2_content3-tracked content1_content2_content3-untracked content1_missing_content1-tracked content1_missing_content1-untracked content1_missing_content3-tracked content1_missing_content3-untracked missing_content2_content2-tracked missing_content2_content2-untracked missing_content2_content3-tracked missing_content2_content3-untracked missing_missing_content3-tracked missing_missing_content3-untracked .gitignore
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content1 content1_content2_content1-tracked.orig
  content2 content1_content2_content1-untracked
  content1 content1_content2_content1-untracked.orig
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content2 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content3 missing_content2_content3-tracked.orig
  content2 missing_content2_content3-untracked
  content3 missing_content2_content3-untracked.orig
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Test revert to "base" content with explicit file name
# -----------------------------------------------------
# (setup from reference repo)

  $ cp -R revert-ref revert-base-explicit-ignored
  $ cd revert-base-explicit-ignored
  $ echo * > .gitignore

# revert all files individually and check the output
# (output is expected to be different than in the --all case)

  >>> revertoutput()
  ### revert for: content1_content1_content1-tracked
  no changes needed to content1_content1_content1-tracked
  ### revert for: content1_content1_content1-untracked
  .
  ### revert for: content1_content1_content3-tracked
  .
  ### revert for: content1_content1_content3-untracked
  .
  ### revert for: content1_content1_missing-tracked
  .
  ### revert for: content1_content1_missing-untracked
  .
  ### revert for: content1_content2_content1-tracked
  .
  ### revert for: content1_content2_content1-untracked
  .
  ### revert for: content1_content2_content2-tracked
  no changes needed to content1_content2_content2-tracked
  ### revert for: content1_content2_content2-untracked
  .
  ### revert for: content1_content2_content3-tracked
  .
  ### revert for: content1_content2_content3-untracked
  .
  ### revert for: content1_content2_missing-tracked
  .
  ### revert for: content1_content2_missing-untracked
  .
  ### revert for: content1_missing_content1-tracked
  .
  ### revert for: content1_missing_content1-untracked
  file not managed: content1_missing_content1-untracked
  ### revert for: content1_missing_content3-tracked
  .
  ### revert for: content1_missing_content3-untracked
  file not managed: content1_missing_content3-untracked
  ### revert for: content1_missing_missing-tracked
  .
  ### revert for: content1_missing_missing-untracked
  content1_missing_missing-untracked: no such file in rev cbcb7147d2a0
  ### revert for: missing_content2_content2-tracked
  no changes needed to missing_content2_content2-tracked
  ### revert for: missing_content2_content2-untracked
  .
  ### revert for: missing_content2_content3-tracked
  .
  ### revert for: missing_content2_content3-untracked
  .
  ### revert for: missing_content2_missing-tracked
  .
  ### revert for: missing_content2_missing-untracked
  .
  ### revert for: missing_missing_content3-tracked
  .
  ### revert for: missing_missing_content3-untracked
  file not managed: missing_missing_content3-untracked
  ### revert for: missing_missing_missing-tracked
  .
  ### revert for: missing_missing_missing-untracked
  missing_missing_missing-untracked: no such file in rev cbcb7147d2a0


# check resulting directory against the --all run
# (There should be no difference)

  >>> print(dircontent())
  content1_content1_content1-tracked content1_content1_content1-untracked content1_content1_content3-tracked content1_content1_content3-untracked content1_content2_content1-tracked content1_content2_content1-untracked content1_content2_content2-tracked content1_content2_content2-untracked content1_content2_content3-tracked content1_content2_content3-untracked content1_missing_content1-tracked content1_missing_content1-untracked content1_missing_content3-tracked content1_missing_content3-untracked missing_content2_content2-tracked missing_content2_content2-untracked missing_content2_content3-tracked missing_content2_content3-untracked missing_missing_content3-tracked missing_missing_content3-untracked .gitignore
  content1 content1_content1_content1-tracked
  content1 content1_content1_content1-untracked
  content1 content1_content1_content3-tracked
  content3 content1_content1_content3-tracked.orig
  content1 content1_content1_content3-untracked
  content3 content1_content1_content3-untracked.orig
  content1 content1_content1_missing-tracked
  content1 content1_content1_missing-untracked
  content2 content1_content2_content1-tracked
  content1 content1_content2_content1-tracked.orig
  content2 content1_content2_content1-untracked
  content1 content1_content2_content1-untracked.orig
  content2 content1_content2_content2-tracked
  content2 content1_content2_content2-untracked
  content2 content1_content2_content3-tracked
  content3 content1_content2_content3-tracked.orig
  content2 content1_content2_content3-untracked
  content3 content1_content2_content3-untracked.orig
  content2 content1_content2_missing-tracked
  content2 content1_content2_missing-untracked
  content1 content1_missing_content1-tracked
  content1 content1_missing_content1-untracked
  content3 content1_missing_content3-tracked
  content3 content1_missing_content3-untracked
  content2 missing_content2_content2-tracked
  content2 missing_content2_content2-untracked
  content2 missing_content2_content3-tracked
  content3 missing_content2_content3-tracked.orig
  content2 missing_content2_content3-untracked
  content3 missing_content2_content3-untracked.orig
  content2 missing_content2_missing-tracked
  content2 missing_content2_missing-untracked
  content3 missing_missing_content3-tracked
  content3 missing_missing_content3-untracked

  $ cd ..

# Revert to an ancestor of P2 during a merge (issue5052)
# -----------------------------------------------------
# (prepare the repository)

  $ sl init issue5052
  $ cd issue5052
  $ echo '*\.orig' > .gitignore
  $ echo 0 > root
  $ sl ci -qAm C0
  $ echo 0 > A
  $ sl ci -qAm C1
  $ echo 1 >> A
  $ sl ci -qm C2
  $ sl up -q 'desc(C0)'
  $ echo 1 > B
  $ sl ci -qAm C3
  $ sl status --rev 'ancestor(.,desc(C2))' --rev 'desc(C2)'
  A A
  $ sl log -G -T '{desc|firstline} ({files})\n'
  @  C3 (B)
  │
  │ o  C2 (A)
  │ │
  │ o  C1 (A)
  ├─╯
  o  C0 (.gitignore root)

# actual tests: reverting to something else than a merge parent

  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl status --rev 'p1()'
  M A
  $ sl status --rev 'p2()'
  A B
  $ sl status --rev 'desc(C1)'
  M A
  A B
  $ sl revert --rev 'desc(C1)' --all
  reverting A
  removing B
  $ sl status --rev 'desc(C1)'

# From the other parents

  $ sl up -C 'p2()'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl status --rev 'p1()'
  M B
  $ sl status --rev 'p2()'
  A A
  $ sl status --rev 'desc(C1)'
  M A
  A B
  $ sl revert --rev 'desc(C1)' --all
  reverting A
  removing B
  $ sl status --rev 'desc(C1)'

#if symlink

# Don't backup symlink reverts

  $ ln -s foo bar
  $ sl add bar
  $ sl commit -m symlink
  $ rm bar
  $ ln -s car bar
  $ sl status
  M bar
  $ sl revert --all --config 'ui.origbackuppath=.hg/origbackups'
  reverting bar
  $ ls .sl/origbackups

#endif
