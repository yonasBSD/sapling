  $ export HGIDENTITY=sl
  $ setconfig diff.git=True
  $ setconfig subtree.allow-any-source-commit=True
  $ setconfig subtree.min-path-depth=1
  $ setconfig drawdag.defaultfiles=false

test warning about changes outside the specified from path

  $ newclientrepo
  $ drawdag <<'EOS'
  > C   # C/bar/y = 1\n2\n3c\n
  > |   # C/foo/x = 1\n2\n3c\n
  > | B # B/foo/x = 1b\n2\n3\n
  > |/  # A/bar/y = 1\n2\n3\n
  > A   # A/foo/x = 1\n2\n3\n
  > EOS
  $ sl go -q $B

  $ sl subtree merge --from-path foo --to-path foo -r $C
  warning: changes outside the specified from_path are ignored!
  (use 'sl status --rev a1383e79789b --rev 531d8f7a5755' to see all changed files)
  merge base: a1383e79789b
  merging foo/x
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (subtree merge, don't forget to commit)
  $ sl status --rev a1383e79789b --rev 531d8f7a5755
  M bar/y
  M foo/x
  $ sl diff
  diff --git a/foo/x b/foo/x
  --- a/foo/x
  +++ b/foo/x
  @@ -1,3 +1,3 @@
   1b
   2
  -3
  +3c
  $ sl go -C . -q

  $ sl subtree merge --from-path foo --to-path foo --from-path bar --to-path bar -r $C
  merge base: a1383e79789b
  merging foo/x
  1 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (subtree merge, don't forget to commit)
  $ sl diff
  diff --git a/bar/y b/bar/y
  --- a/bar/y
  +++ b/bar/y
  @@ -1,3 +1,3 @@
   1
   2
  -3
  +3c
  diff --git a/foo/x b/foo/x
  --- a/foo/x
  +++ b/foo/x
  @@ -1,3 +1,3 @@
   1b
   2
  -3
  +3c
  $ sl ci -m "merge foo and bar"
  $ sl subtree inspect -r .
  {
    "merges": [
      {
        "version": 1,
        "from_commit": "531d8f7a575503618e6891284405bb00ffd8d977",
        "from_path": "bar",
        "to_path": "bar"
      },
      {
        "version": 1,
        "from_commit": "531d8f7a575503618e6891284405bb00ffd8d977",
        "from_path": "foo",
        "to_path": "foo"
      }
    ]
  }
