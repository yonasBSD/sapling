  $ export HGIDENTITY=sl
  $ setconfig drawdag.defaultfiles=false

  $ newclientrepo
  $ drawdag <<EOS
  > A  # A/foo/bar/file1 = content1\n
  >    # A/foo/bar/file2 = content2\n
  >    # A/foo/baz/file3 = content3\n
  >    # A/foo/baz/qux/file4 = content4\n
  >    # A/other = other\n
  > EOS
  $ sl go -q $A

Test that FILE is required:
  $ sl debughash
  abort: PATTERN required
  [255]

Test basic debughash - hashing all files:
  $ sl debughash .
  * (glob)

Test debughash is deterministic:
  $ HASH_ALL=$(sl debughash .)
  $ test "$HASH_ALL" = "$(sl debughash .)"

Test hashing a specific directory:
  $ HASH_FOO=$(sl debughash foo)
  $ test -n "$HASH_FOO"
  $ test "$HASH_FOO" != "$HASH_ALL"

Test hashing a specific subdirectory:
  $ HASH_BAR=$(sl debughash foo/bar)
  $ test -n "$HASH_BAR"
  $ test "$HASH_BAR" != "$HASH_FOO"

Test excluding a file changes the hash:
  $ HASH_EXCLUDE=$(sl debughash foo -X foo/baz/file3)
  $ test "$HASH_EXCLUDE" != "$HASH_FOO"

Test excluding a file that is not in the path doesn't change the hash:
  $ HASH_EXCLUDE_OTHER=$(sl debughash foo/bar -X other)
  $ test "$HASH_EXCLUDE_OTHER" = "$HASH_BAR"

Test excluding all files in a directory produces the same hash as not including it:
  $ HASH_JUST_BAR=$(sl debughash foo -X 'foo/baz/**')
  $ test "$HASH_JUST_BAR" = "$HASH_BAR"

Test -I (include) narrows scope - files outside are ignored:
  $ HASH_INCLUDE=$(sl debughash . -I 'foo/bar/**')
  $ test -n "$HASH_INCLUDE"
  $ test "$HASH_INCLUDE" != "$HASH_ALL"
  $ test "$HASH_INCLUDE" = "$(sl debughash . -I 'foo/bar/**')"

Test with --rev:
  $ HASH_REV=$(sl debughash . -r $A)
  $ test "$HASH_REV" = "$HASH_ALL"

Test empty match produces null hash:
  $ sl debughash nonexistent
  0000000000000000000000000000000000000000

Test from a subdirectory:
  $ cd foo
  $ HASH_FROM_SUB=$(sl debughash bar)
  $ test "$HASH_FROM_SUB" = "$HASH_BAR"
  $ cd ..

Test that modifying a file changes the hash:
  $ drawdag <<EOS
  > B  # B/foo/bar/file1 = modified\n
  > |
  > A
  > EOS
  $ sl go -q $B
  $ HASH_MODIFIED=$(sl debughash .)
  $ test "$HASH_MODIFIED" != "$HASH_ALL"

Test that modifying an excluded file does NOT change the hash:
  $ HASH_B_EXCLUDE=$(sl debughash . -X foo/bar/file1)
  $ sl go -q $A
  $ HASH_A_EXCLUDE=$(sl debughash . -X foo/bar/file1)
  $ test "$HASH_B_EXCLUDE" = "$HASH_A_EXCLUDE"

Test file name is included in hash:
  $ newclientrepo
  $ drawdag <<EOS
  > A  # A/dir1/a = content\n
  >    # A/dir1/exclude = exclude\n
  >    # A/dir2/b = content\n
  >    # A/dir2/exclude = exclude\n
  > EOS
  $ test $(sl debughash -r $A dir1 -X 'glob:**/exclude') != $(sl debughash -r $A dir2 -X 'glob:**/exclude')

Test debughash with uncommitted changes (wdir):
  $ newclientrepo wdir_test
  $ mkdir -p foo/bar foo/baz
  $ echo content1 > foo/bar/file1
  $ echo content2 > foo/bar/file2
  $ echo content3 > foo/baz/file3
  $ sl commit -Aqm 'initial'
  $ HASH_COMMITTED=$(sl debughash .)

Modify a file and verify wdir hash changes:
  $ echo modified > foo/bar/file1
  $ HASH_WDIR=$(sl debughash .)
  $ test "$HASH_WDIR" != "$HASH_COMMITTED"

Test that wdir hash is deterministic:
  $ test "$HASH_WDIR" = "$(sl debughash .)"

Test that excluding the modified file gives same hash as committed:
  $ HASH_WDIR_EXCLUDE=$(sl debughash . -X foo/bar/file1)
  $ HASH_COMMITTED_EXCLUDE=$(sl debughash . -X foo/bar/file1 -r .)
  $ test "$HASH_WDIR_EXCLUDE" = "$HASH_COMMITTED_EXCLUDE"

Test that unmodified subtree hash is unchanged:
  $ HASH_BAZ_WDIR=$(sl debughash foo/baz)
  $ HASH_BAZ_COMMITTED=$(sl debughash foo/baz -r .)
  $ test "$HASH_BAZ_WDIR" = "$HASH_BAZ_COMMITTED"

Revert the uncommitted change and verify hash returns to committed:
  $ sl revert foo/bar/file1
  $ HASH_REVERTED=$(sl debughash .)
  $ test "$HASH_REVERTED" = "$HASH_COMMITTED"
