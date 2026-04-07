#require xargs env python3 no-eden

  $ enable rebase

Set up the repository with some simple files.
This is coupled with the files dictionary in
eden/scm/tests/fake-biggrep-client.py
  $ sl init repo
  $ cd repo
  $ mkdir grepdir
  $ cd grepdir
  $ echo 'foobarbaz' > grepfile1
  $ echo 'foobarboo' > grepfile2
  $ printf '%s\n' '-g' > grepfile3
  $ mkdir subdir1
  $ echo 'foobar_subdir' > subdir1/subfile1
  $ mkdir subdir2
  $ echo 'foobar_dirsub' > subdir2/subfile2
  $ sl add grepfile1
  $ sl add grepfile2
  $ sl add subdir1/subfile1
  $ sl add subdir2/subfile2
  $ sl commit -m "Added some files"
  $ echo 'foobarbazboo' > untracked1

Make sure grep finds patterns in tracked files, and excludes untracked files
  $ sl grep -n foobar
  grepfile1:1:foobarbaz
  grepfile2:1:foobarboo
  subdir1/subfile1:1:foobar_subdir
  subdir2/subfile2:1:foobar_dirsub
  $ sl grep -n barbaz
  grepfile1:1:foobarbaz
  $ sl grep -n barbaz .
  grepfile1:1:foobarbaz

Test searching in subdirectories, from the repository root
  $ sl grep -n foobar subdir1
  subdir1/subfile1:1:foobar_subdir
  $ sl grep -n foobar sub*
  subdir1/subfile1:1:foobar_subdir
  subdir2/subfile2:1:foobar_dirsub

Test searching in a sibling subdirectory, using a relative path
  $ cd subdir1
  $ sl grep -n foobar ../subdir2
  ../subdir2/subfile2:1:foobar_dirsub
  $ sl grep -n foobar
  subfile1:1:foobar_subdir
  $ sl grep -n foobar .
  subfile1:1:foobar_subdir
  $ cd ..

Test mercurial file patterns
  $ sl grep -n foobar 'glob:*rep*'
  grepfile1:1:foobarbaz
  grepfile2:1:foobarboo

Test using alternative grep commands
  $ sl grep -i FooBarB
  grepfile1:foobarbaz
  grepfile2:foobarboo
#if osx
  $ sl grep FooBarB
  [1]
#else
  $ sl grep FooBarB
  [1]
#endif

Test --include flag
  $ sl grep --include '**/*file1' -n foobar
  grepfile1:1:foobarbaz
  subdir1/subfile1:1:foobar_subdir
  $ sl grep -I '**/*file1' -n foobar
  grepfile1:1:foobarbaz
  subdir1/subfile1:1:foobar_subdir

Test --exclude flag
  $ sl grep --exclude '**/*file1' -n foobar
  grepfile2:1:foobarboo
  subdir2/subfile2:1:foobar_dirsub
  $ sl grep -X '**/*file1' -n foobar
  grepfile2:1:foobarboo
  subdir2/subfile2:1:foobar_dirsub

Test --include and --exclude flags together
  $ sl grep --include '**/*file1' --exclude '**/grepfile1' -n foobar
  subdir1/subfile1:1:foobar_subdir
  $ sl grep -I '**/*file1' -X '**/grepfile1' -n foobar
  subdir1/subfile1:1:foobar_subdir

#if symlink no-osx
Test symlinks
  $ echo file_content > target_file
  $ ln -s target_file sym_link
  $ sl add sym_link
  $ sl grep file_content
  [1]
#endif

  $ setconfig grep.biggrepclient=$TESTDIR/fake-biggrep-client.py grep.usebiggrep=True grep.biggrepcorpus=fake grep.biggreptier=biggrep.master

Test with context
  $ BIGGREP_FILES='{"grepdir/grepfile1": "foobarbaz", "grepdir/grepfile2": "foobarboo", "grepdir/subdir1/subfile1": "foobar_subdir", "grepdir/subdir2/subfile2": "foobar_dirsub"}' \
  > sl grep --color=off -n foobar | sort
  grepfile1:1:foobarbaz_bg
  grepfile2:1:foobarboo_bg
  subdir1/subfile1:1:foobar_subdir_bg
  subdir2/subfile2:1:foobar_dirsub_bg

Test basic biggrep client in subdir1
  $ BIGGREP_FILES='{"grepdir/subdir1/subfile1": "foobar_subdir"}' \
  > sl grep --cwd subdir1 foobar | sort
  subfile1:foobar_subdir_bg

Test basic biggrep client with subdir2 matcher
  $ BIGGREP_FILES='{"grepdir/subdir2/subfile2": "foobar_dirsub"}' \
  > sl grep foobar subdir2 | sort
  subdir2/subfile2:foobar_dirsub_bg

Test biggrep searching in a sibling subdirectory, using a relative path
  $ cd subdir1
  $ BIGGREP_FILES='{"grepdir/subdir2/subfile2": "foobar_dirsub"}' \
  > sl grep foobar ../subdir2 -n | sort
  ../subdir2/subfile2:1:foobar_dirsub_bg
  $ BIGGREP_FILES='{"grepdir/subdir1/subfile1": "foobar_subdir"}' \
  > sl grep -n foobar | sort
  subfile1:1:foobar_subdir_bg
  $ BIGGREP_FILES='{"grepdir/subdir1/subfile1": "foobar_subdir"}' \
  > sl grep -n foobar . | sort
  subfile1:1:foobar_subdir_bg
  $ cd ..

Test escaping of dashes in biggrep expression:
  $ BIGGREP_FILES='{"grepdir/grepfile3": "-g"}' \
  > sl grep -- -g | sort
  grepfile3:-g_bg

Test biggrep command debug info
  $ cd subdir1
  $ BIGGREP_FILES='{"grepdir/subdir1/subfile1": "foobar_subdir"}' \
  > sl grep foobar -n --debug
  biggrep command: ["*/fake-biggrep-client.py", "biggrep.master", "fake", "re2", "--stripdir", "-r", "--expression", "foobar", "-f", "(grepdir/subdir1)"] (glob)
  subfile1:1:foobar_subdir_bg
  $ cd ..

Test biggrep command error handling
  $ sl grep --config grep.biggrepclient=$TESTDIR/broken-biggrep-client.py foobar
  abort: biggrep_client failed with exit code 2: broken biggrepclient
  (pass `--config grep.usebiggrep=False` to bypass biggrep)
  [255]

Test biggrep with JSON output (-T json):
  $ BIGGREP_FILES='{"grepdir/grepfile1": "foobarbaz"}' \
  > sl grep --config grep.biggrepclient=$TESTDIR/fake-biggrep-client.py \
  > --config grep.usebiggrep=True --config grep.biggrepcorpus=fake \
  > -T json foobar grepfile1
  [
    {"path":"grepfile1","text":"foobarbaz_bg"}
  ]

Test biggrep with JSON output and line numbers:
  $ BIGGREP_FILES='{"grepdir/grepfile1": "foobarbaz"}' \
  > sl grep --config grep.biggrepclient=$TESTDIR/fake-biggrep-client.py \
  > --config grep.usebiggrep=True --config grep.biggrepcorpus=fake \
  > -T json -n foobar grepfile1
  [
    {"path":"grepfile1","line_number":1,"text":"foobarbaz_bg"}
  ]

Test biggrep with JSON Lines output (-T jsonl):
  $ BIGGREP_FILES='{"grepdir/grepfile1": "foobarbaz", "grepdir/grepfile2": "foobarboo"}' \
  > sl grep --config grep.biggrepclient=$TESTDIR/fake-biggrep-client.py \
  > --config grep.usebiggrep=True --config grep.biggrepcorpus=fake \
  > -T jsonl foobar grepfile1 grepfile2 | sort
  {"path":"grepfile1","text":"foobarbaz_bg"}
  {"path":"grepfile2","text":"foobarboo_bg"}

Test biggrep with JSON output and -l (files with matches):
  $ BIGGREP_FILES='{"grepdir/grepfile1": "foobarbaz", "grepdir/grepfile2": "foobarboo"}' \
  > sl grep --config grep.biggrepclient=$TESTDIR/fake-biggrep-client.py \
  > --config grep.usebiggrep=True --config grep.biggrepcorpus=fake \
  > -T json -l foobar grepfile1 grepfile2 | pp --sort
  [
    {
      "path": "grepfile1"
    },
    {
      "path": "grepfile2"
    }
  ]
