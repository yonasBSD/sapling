# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

CACHEDIR="$TESTTMP/hgcache"
export DUMMYSSH_STABLE_ORDER=1
cat >> $HGRCPATH <<EOF
[remotefilelog]
cachepath=$CACHEDIR
debug=True
[extensions]
remotefilelog=
rebase=
[ui]
ssh=$(dummysshcmd)
[server]
preferuncompressed=True
[experimental]
changegroup3=True
[rebase]
singletransaction=True
EOF

_cachecount=0

newcachedir() {
  _cachecount=$((_cachecount+1))
  CACHEDIR="$TESTTMP/hgcache$_cachecount"
  setconfig remotefilelog.cachepath="$CACHEDIR"
}

hgcloneshallow() {
  local name
  local dest
  orig=$1
  shift
  dest=$1
  shift
  hg clone --config remotefilelog.reponame=master $orig $dest $@
  cat >> $dest/.hg/hgrc <<EOF
[remotefilelog]
reponame=master
[phases]
publish=False
EOF
}

hginit() {
  local name
  name=$1
  shift
  hg init $name $@ --config remotefilelog.reponame=master
}

clearcache() {
  rm -rf $CACHEDIR/*
}

mkcommit() {
  echo "$1" > "$1"
  hg add "$1"
  hg ci -m "$1"
}

ls_l() {
  $PYTHON $TESTDIR/ls-l.py "$@"
}

findfilessorted() {
  find "$1" -type f | sort
}
