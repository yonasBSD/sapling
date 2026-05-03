#require git no-windows no-eden symlink

  $ . $TESTDIR/git.sh
  $ enable smartlog

Set up small project repos to simulate repos managed by the repo tool.
project-a is the outer project at vendor/a; project-c is a nested project at
vendor/a/sub/c. In real-world .repo workspaces, vendor/a/.git does not
manage vendor/a/sub/c because a .gitignore at vendor/a/sub/.gitignore
excludes its subdirectories.

  $ git init -q -b main project-a
  $ cd project-a
  $ echo "project-a content" > README
  $ git add README && git commit -qm 'init a'
  $ A_REV=$(git rev-parse HEAD)
  $ cd ..

  $ git init -q -b main project-b
  $ cd project-b
  $ echo "project-b content" > README
  $ git add README && git commit -qm 'init b'
  $ B_REV=$(git rev-parse HEAD)
  $ cd ..

  $ git init -q -b main project-c
  $ cd project-c
  $ echo "project-c content" > README
  $ git add README && git commit -qm 'init c'
  $ C_REV=$(git rev-parse HEAD)
  $ cd ..

  $ mkdir repodir && cd repodir

Set up .repo/manifests as its own git repo with .git symlinked to manifests.git:

  $ git init -q -b main .repo/manifests
  $ mv .repo/manifests/.git .repo/manifests.git
  $ ln -s ../manifests.git .repo/manifests/.git
  $ mkdir -p .repo/manifests/static
  $ cat > .repo/manifests/static/static.xml << EOF
  > <?xml version="1.0" encoding="UTF-8"?>
  > <manifest>
  >   <remote name="origin" fetch="file://$TESTTMP"/>
  >   <default revision="main" remote="origin"/>
  >   <project name="project-a" path="vendor/a" revision="$A_REV"/>
  >   <project name="project-b" path="frameworks/b" revision="$B_REV"/>
  >   <project name="project-c" path="vendor/a/sub/c" revision="$C_REV"/>
  > </manifest>
  > EOF
  $ cd .repo/manifests && git add static/static.xml && git commit -qm 'add manifest' && cd ../..

Set up projects with .git symlinks back to .repo/projects/:

  $ mkdir -p .repo/projects/vendor .repo/projects/frameworks
  $ git clone -q file://$TESTTMP/project-a vendor/a
  $ mv vendor/a/.git .repo/projects/vendor/a.git
  $ ln -s ../../.repo/projects/vendor/a.git vendor/a/.git

  $ git clone -q file://$TESTTMP/project-b frameworks/b
  $ mv frameworks/b/.git .repo/projects/frameworks/b.git
  $ ln -s ../../.repo/projects/frameworks/b.git frameworks/b/.git

vendor/a/.git does not manage vendor/a/sub/c because of the .gitignore at
vendor/a/sub/.gitignore. project-c is cloned in underneath as its own 
independent git repo:

  $ mkdir -p vendor/a/sub
  $ cat > vendor/a/sub/.gitignore << 'EOF'
  > # ignore all subdirs
  > */
  > EOF
  $ git clone -q file://$TESTTMP/project-c vendor/a/sub/c
  $ mv vendor/a/sub/c/.git .repo/projects/vendor/a/sub/c.git
  $ ln -s ../../../../.repo/projects/vendor/a/sub/c.git vendor/a/sub/c/.git

Add a top-level file:

  $ echo "top-level file" > BUILD

Add "enable_sl" file which is used as a config flag for identity:

  $ touch .repo/enable_sl

Sapling recognizes .repo identity
  $ sl root
  $TESTTMP/repodir

  $ sl smartlog -T '{desc}'
  @  add manifest

clean status
  $ sl status
  abort: synthesizing tree for root *: failure inserting 'vendor/a/sub/c' in manifest: 'vendor/a' is already a file (glob)
  [255]

  $ sl log -r . -T "desc:\n  {desc}\nfiles:\n{files % '  {file}\n'}"
  abort: synthesizing tree for root * (glob)
  
  Caused by:
      0: failure inserting 'vendor/a/sub/c' in manifest
      1: 'vendor/a' is already a file
  [255]

modified outer project is reported by status
  $ cd vendor/a
  $ echo "project vendor/a" > README
  $ git add README && git commit -qm 'add README'
  $ cd ../..
  $ sl status
  abort: synthesizing tree for root *: failure inserting 'vendor/a/sub/c' in manifest: 'vendor/a' is already a file (glob)
  [255]

Diff shows subproject commit change for the outer project:

  $ sl diff 
  abort: synthesizing tree for root * (glob)
  
  Caused by:
      0: failure inserting 'vendor/a/sub/c' in manifest
      1: 'vendor/a' is already a file
  [255]

Modified nested (overlapping) project is reported by status:

  $ cd vendor/a/sub/c
  $ echo "project vendor/a/sub/c" > README
  $ git add README && git commit -qm 'modify c'
  $ cd ../../../..
  $ sl status
  abort: synthesizing tree for root *: failure inserting 'vendor/a/sub/c' in manifest: 'vendor/a' is already a file (glob)
  [255]

Exact-path diff also works for the nested overlapping project:

  $ sl diff vendor/a/sub/c
  abort: synthesizing tree for root * (glob)
  
  Caused by:
      0: failure inserting 'vendor/a/sub/c' in manifest
      1: 'vendor/a' is already a file
  [255]

Modified non-overlapping project is reported by status:

  $ cd frameworks/b
  $ echo "project frameworks/b" > README
  $ git add README && git commit -qm 'modify b'
  $ cd ../..
  $ sl status
  abort: synthesizing tree for root *: failure inserting 'vendor/a/sub/c' in manifest: 'vendor/a' is already a file (glob)
  [255]

Exact-path diff also works for the non-overlapping project:

  $ sl diff frameworks/b
  abort: synthesizing tree for root * (glob)
  
  Caused by:
      0: failure inserting 'vendor/a/sub/c' in manifest
      1: 'vendor/a' is already a file
  [255]
