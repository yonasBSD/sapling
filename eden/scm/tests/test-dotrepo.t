#require git no-windows no-eden symlink

  $ . $TESTDIR/git.sh
  $ enable smartlog

Set up small project repos to simulate repos managed by the repo tool:

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

Add a top-level file:

  $ echo "top-level file" > BUILD

Add "enable_sl" file which is used as a config flag for identity:

  $ touch .repo/enable_sl

Sapling recognizes .repo identity
  $ sl root
  $TESTTMP/repodir

(bad: sl smartlog does not work correctly in .repo)
  $ sl smartlog -T '{desc}'
  o  add manifest

(bad: sl status does not work in .repo)
(not running to avoid noises)
$ sl status

(bad: sl log does not work in .repo)

  $ sl log -r . -T '{desc}\n'
