
#require no-eden



  $ enable sparse
  $ newclientrepo myrepo
  $ touch a
  $ sl commit -Aqm a
  $ sl rm a
  $ cat > .sl/sparse <<EOF
  > [exclude]
  > a
  > EOF

We should filter out "a" since it isn't included in the sparse profile.
  $ sl status
