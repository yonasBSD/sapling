
#require no-eden


  $ eagerepo

  $ configure modern
  $ newrepo basic
  $ drawdag << 'EOS'
  > D
  > |
  > C E   # C/A=(removed)
  > |/    # C/B=B1
  > B
  > |
  > A
  > EOS
  $ sl up -qC $D

should complain

  $ sl backout
  abort: please specify a revision to backout
  [255]
  $ sl backout -r $A $B
  abort: please specify just one revision
  [255]
  $ sl backout $E
  abort: cannot backout change that is not an ancestor
  [255]

basic operation

  $ sl backout -d '1000 +0800' $C --no-edit
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  changeset d2f56590172c backs out changeset 2e4218cf3ee0

backout of backout is as if nothing happened

  $ sl backout -d '2000 +0800' tip --no-edit
  removing A
  reverting B
  adding C
  changeset 6916acf22814 backs out changeset d2f56590172c

check the changes

  $ sl log -Gr 'desc(Back)' -T '{desc}' -p --config diff.git=1
  @  Back out "Back out "C""
  │
  │  Original commit changeset: d2f56590172cdiff --git a/A b/A
  │  deleted file mode 100644
  │  --- a/A
  │  +++ /dev/null
  │  @@ -1,1 +0,0 @@
  │  -A
  │  \ No newline at end of file
  │  diff --git a/B b/B
  │  --- a/B
  │  +++ b/B
  │  @@ -1,1 +1,1 @@
  │  -B
  │  \ No newline at end of file
  │  +B1
  │  \ No newline at end of file
  │  diff --git a/C b/C
  │  new file mode 100644
  │  --- /dev/null
  │  +++ b/C
  │  @@ -0,0 +1,1 @@
  │  +C
  │  \ No newline at end of file
  │
  o  Back out "C"
  │
  ~  Original commit changeset: 2e4218cf3ee0diff --git a/A b/A
     new file mode 100644
     --- /dev/null
     +++ b/A
     @@ -0,0 +1,1 @@
     +A
     \ No newline at end of file
     diff --git a/B b/B
     --- a/B
     +++ b/B
     @@ -1,1 +1,1 @@
     -B1
     \ No newline at end of file
     +B
     \ No newline at end of file
     diff --git a/C b/C
     deleted file mode 100644
     --- a/C
     +++ /dev/null
     @@ -1,1 +0,0 @@
     -C
     \ No newline at end of file
  
test --no-commit

  $ sl up -qC $E
  $ sl backout --no-commit .
  removing E
  changeset 49cb92066bfd backed out, don't forget to commit.
  $ sl diff --config diff.git=1
  diff --git a/E b/E
  deleted file mode 100644
  --- a/E
  +++ /dev/null
  @@ -1,1 +0,0 @@
  -E
  \ No newline at end of file

  $ cd ..

Test backing out a mv keeps the blame history even if copytracing is off
  $ sl init mv-backout
  $ cd mv-backout
  $ setconfig copytrace.dagcopytrace=False
  $ echo a > foo
  $ sl commit -Aqm a
  $ echo b >> foo
  $ sl commit -Aqm b
  $ sl mv foo bar
  $ sl commit -Aqm move
  $ sl backout -r . -m backout
  removing bar
  adding foo
  changeset b53c2dfb1fb7 backs out changeset 863da64a0012
  $ sl status --change . -C
  A foo
    bar
  R bar
  $ sl blame -c foo
  3e92d79f743a: a
  998f4c3a2bdf: b

  $ cd ..

Make sure editor sees proper message
  $ sl init backout-msg
  $ cd backout-msg
  $ echo a > foo
  $ sl commit -Aqm a
  $ echo b > bar
  $ sl commit -Aqm b
No output means editor was not invoked
  $ HGEDITOR=cat sl backout .
  removing bar
  changeset 4dc95485382f backs out changeset 20b005551096
Now we see the default commit message
  $ sl up -qC 'desc(b)'
  $ HGEDITOR=cat sl backout . --edit
  adding bar
  Back out "Back out "b""
  
  Original commit changeset: 4dc95485382f
  
  
  SL: Enter commit message.  Lines beginning with 'SL:' are removed.
  SL: Leave message empty to abort commit.
  SL: --
  SL: user: test
  SL: added bar
  changeset 9b702c98cd4b backs out changeset 4dc95485382f

Test with conflicts (interesting because there are no merge labels):
  $ newclientrepo
  $ drawdag << 'EOS'
  > C  # C/foo=three
  > |
  > B  # B/foo=two
  > |
  > A  # A/foo=one
  > EOS
  $ sl go -q $C
  $ sl backout $B --tool :prompt
  keep (l)ocal, take (o)ther, or leave (u)nresolved for foo? u
  0 files updated, 0 files merged, 1 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]
