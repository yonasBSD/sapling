#require fsmonitor no-eden

  $ export HGIDENTITY=sl
  $ newclientrepo

Ensure that, when files in the root are ignored and there is an exclusion, that sl status returns the correct value

  $ cat > .gitignore << 'EOF'
  > /*
  > !/foobar
  > EOF
  $ sl status
  $ mkdir foobar
  $ touch root-file foobar/foo # adds files to root and to foobar
  $ sl status
  ? foobar/foo
  $ sl status # run it a second time to ensure that we didn't accidentally exclude the file
  ? foobar/foo
