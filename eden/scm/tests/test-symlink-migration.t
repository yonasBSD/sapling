#inprocess-hg-incompatible
#require symlink windows no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable sparse
  $ setconfig unsafe.filtersuspectsymlink=False
  $ setconfig commands.force-rust=clone

Create a repo to be cloned
  $ newrepo origin
  $ setconfig paths.default=test:e1
  $ cat > all.sparse <<EOF
  > [include]
  > *
  > EOF
  $ mkdir -p a/b
  $ echo sup > a/b/c
  $ mkdir x
  $ ln -s ../a/b/c x/file
  $ ln -s ../a/b x/dir
  $ sl commit -Am "commit with symlinks" -q
  $ sl push -r . --to master --create -q
  $ sl debugtreestate list | grep x
  x/dir: 0120777 0 * EXIST_P1 EXIST_NEXT * (glob)
  x/file: 0120666 0 * EXIST_P1 EXIST_NEXT * (glob)

Clone the repo with symlinks disabled and verify that files are regular
TODO(sggutier): figure out why shallow is necessary here (replacing test with eager renders the same results)
  $ cd
  $ sl clone --enable-profile all.sparse test:e1 cloned --config experimental.windows-symlinks=False -q
  $ cd cloned
  $ sl st
  $ sl go master -q
  $ sl st
  $ sl debugtreestate list | grep x
  x/dir: 0666 6 * EXIST_P1 EXIST_NEXT * (glob)
  x/file: 0666 8 * EXIST_P1 EXIST_NEXT * (glob)
  $ cat .sl/requires | grep -v windowssymlinks > .sl/requires
  $ sl st
  $ cat x/file
  ../a/b/c (no-eol)
  $ cat x/dir
  ../a/b (no-eol)

Test migration for enabling symlinks
  $ sl debugmigratesymlinks
  Enabling symlinks for the repo...
  Symlinks enabled for the repo
  $ sl debugtreestate list | grep x
  x/dir: 0120777 0 * EXIST_P1 EXIST_NEXT NEED_CHECK  (glob)
  x/file: 0120666 0 * EXIST_P1 EXIST_NEXT NEED_CHECK  (glob)
  $ cat x/file
  sup
  $ ls x/dir/
  c
  $ sl st

Test migration for disabling symlinks
  $ sl debugmigratesymlinks disable
  Disabling symlinks for the repo...
  Symlinks disabled for the repo
  $ sl st
  $ sl debugtreestate list | grep x
  x/dir: 0666 6 * EXIST_P1 EXIST_NEXT * (glob)
  x/file: 0666 8 * EXIST_P1 EXIST_NEXT * (glob)
  $ cat x/file
  ../a/b/c (no-eol)
  $ cat x/dir
  ../a/b (no-eol)

Test that migration ignores modified files
  $ echo "I have been modified" > x/dir
  $ sl debugmigratesymlinks enable
  Enabling symlinks for the repo...
  Symlinks enabled for the repo
  $ sl debugtreestate list | grep x
  x/dir: 0666 6 * EXIST_P1 EXIST_NEXT * (glob)
  x/file: 0120666 0 * EXIST_P1 EXIST_NEXT NEED_CHECK * (glob)
  $ sl st
  M x/dir
  $ cat x/dir
  I have been modified
  $ cat x/file
  sup
