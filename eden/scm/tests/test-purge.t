
#require no-eden


init

  $ eagerepo
  $ sl init t
  $ cd t
  $ setconfig purge.dirs-by-default=True

setup

  $ echo r1 > r1
  $ sl ci -qAmr1 -d'0 0'
  $ mkdir directory
  $ echo r2 > directory/r2
  $ sl ci -qAmr2 -d'1 0'
  $ echo 'ignored' > .gitignore
  $ sl ci -qAmr3 -d'2 0'

delete an empty directory

  $ mkdir empty_dir
  $ sl purge -p -v
  empty_dir
  $ sl purge -v
  removing directory empty_dir
  $ ls
  directory
  r1

delete an untracked directory

  $ mkdir untracked_dir
  $ touch untracked_dir/untracked_file1
  $ touch untracked_dir/untracked_file2
  $ sl purge -p
  untracked_dir/untracked_file1
  untracked_dir/untracked_file2
  $ sl purge -v
  removing file untracked_dir/untracked_file1
  removing file untracked_dir/untracked_file2
  removing directory untracked_dir
  $ ls
  directory
  r1

delete an untracked file

  $ touch untracked_file
  $ touch untracked_file_readonly
  $ $PYTHON <<EOF
  > import os, stat
  > f= 'untracked_file_readonly'
  > os.chmod(f, stat.S_IMODE(os.stat(f).st_mode) & ~stat.S_IWRITE)
  > EOF
  $ sl purge -p
  untracked_file
  untracked_file_readonly
  $ sl purge -v
  removing file untracked_file
  removing file untracked_file_readonly
  $ ls
  directory
  r1

delete an untracked file in a tracked directory

  $ touch directory/untracked_file
  $ sl purge -p
  directory/untracked_file
  $ sl purge -v
  removing file directory/untracked_file
  $ ls
  directory
  r1

delete nested directories

  $ mkdir -p untracked_directory/nested_directory
  $ sl purge -p
  untracked_directory/nested_directory
  $ sl purge -v
  removing directory untracked_directory/nested_directory
  removing directory untracked_directory
  $ ls
  directory
  r1

delete nested directories from a subdir

  $ mkdir -p untracked_directory/nested_directory
  $ cd directory
  $ sl purge -p
  untracked_directory/nested_directory
  $ sl purge -v
  removing directory untracked_directory/nested_directory
  removing directory untracked_directory
  $ cd ..
  $ ls
  directory
  r1

delete only part of the tree

  $ mkdir -p untracked_directory/nested_directory
  $ touch directory/untracked_file
  $ cd directory
  $ sl purge -p ../untracked_directory
  untracked_directory/nested_directory
  $ sl purge -v ../untracked_directory
  removing directory untracked_directory/nested_directory
  removing directory untracked_directory
  $ cd ..
  $ ls
  directory
  r1
  $ ls directory/untracked_file
  directory/untracked_file
  $ rm directory/untracked_file

skip ignored files if --all not specified

  $ touch ignored
  $ sl purge -p
  $ sl purge -v
  $ ls
  directory
  ignored
  r1
  $ sl purge -p --all
  ignored
  $ sl purge -v --all
  removing file ignored
  $ ls
  directory
  r1

abort with missing files until we support name mangling filesystems

  $ touch untracked_file
  $ rm r1

hide error messages to avoid changing the output when the text changes

  $ sl purge -p 2> /dev/null
  untracked_file
  $ sl st
  ! r1
  ? untracked_file

  $ sl purge -p
  untracked_file
  $ sl purge -v 2> /dev/null
  removing file untracked_file
  $ sl st
  ! r1

  $ sl purge -v
  $ sl revert --all --quiet
  $ sl st -a

tracked file in ignored directory (issue621)

  $ echo directory >> .gitignore
  $ sl ci -m 'ignore directory'
  $ touch untracked_file
  $ sl purge -p
  untracked_file
  $ sl purge -v
  removing file untracked_file

skip excluded files

  $ touch excluded_file
  $ sl purge -p -X excluded_file
  $ sl purge -v -X excluded_file
  $ ls
  directory
  excluded_file
  r1
  $ rm excluded_file

skip files in excluded dirs

  $ mkdir excluded_dir
  $ touch excluded_dir/file
  $ sl purge -p -X excluded_dir
  $ sl purge -v -X excluded_dir
  $ ls
  directory
  excluded_dir
  r1
  $ ls excluded_dir
  file
  $ rm -R excluded_dir

skip excluded empty dirs

  $ mkdir excluded_dir
  $ sl purge -p -X excluded_dir
  $ sl purge -v -X excluded_dir
  $ ls
  directory
  excluded_dir
  r1
  $ rmdir excluded_dir

skip patterns

  $ mkdir .svn
  $ touch .svn/foo
  $ mkdir directory/.svn
  $ touch directory/.svn/foo
  $ sl purge -p -X .svn -X '*/.svn'
  $ sl purge -p -X re:.*.svn

  $ rm -R .svn directory r1

only remove files

  $ mkdir -p empty_dir dir
  $ touch untracked_file dir/untracked_file
  $ sl purge -p --files
  dir/untracked_file
  untracked_file
  $ sl purge -v --files
  removing file dir/untracked_file
  removing file untracked_file
  $ ls
  dir
  empty_dir
  $ ls dir

only remove dirs

  $ mkdir -p empty_dir dir
  $ touch untracked_file dir/untracked_file
  $ sl purge -p --dirs
  empty_dir
  $ sl purge -v --dirs
  removing directory empty_dir
  $ ls
  dir
  untracked_file
  $ ls dir
  untracked_file

remove both files and dirs

  $ mkdir -p empty_dir dir
  $ touch untracked_file dir/untracked_file
  $ sl purge -p --files --dirs
  dir/untracked_file
  untracked_file
  empty_dir
  $ sl purge -v --files --dirs
  removing file dir/untracked_file
  removing file untracked_file
  removing directory empty_dir
  removing directory dir
  $ ls

remove only files when purge.dirs-by-default=False

  $ setconfig purge.dirs-by-default=False
  $ mkdir empty_dir
  $ touch untracked_file
  $ sl purge -v
  removing file untracked_file
  $ ls
  empty_dir

  $ cd ..
