#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

INFINITEPUSH_TESTDIR="${RUN_TESTS_LIBRARY:-"$TESTDIR"}"

scratchnodes() {
  for node in `find ../repo/.sl/scratchbranches/index/nodemap -type f | LC_ALL=C sort`; do
     echo ${node##*/} `cat $node`
  done
}

scratchbookmarks() {
  for bookmark in `find ../repo/.sl/scratchbranches/index/bookmarkmap -type f | LC_ALL=C sort`; do
     echo "${bookmark##*/bookmarkmap/} `cat $bookmark`"
  done
}

setupcommon() {
  cat >> $HGRCPATH << EOF
[extensions]
commitcloud=
fbcodereview=
[ui]
ssh=$(dummysshcmd)
[infinitepush]
branchpattern=re:scratch/.*
bgssh=$(dummysshcmd) -bgssh
[remotenames]
autopullhoistpattern=re:^[a-z0-9A-Z/]*$
hoist=default
[commitcloud]
upload_retry_attempts=1
EOF
}

setupserver() {
cat >> "$(_dotdir_configfile)" << EOF
[infinitepush]
server=yes
EOF
}

waitbgbackup() {
  sleep 1
  sl debugwaitbackup
}

mkcommitautobackup() {
    echo $1 > $1
    sl add $1
    sl ci -m $1 --config infinitepushbackup.autobackup=True
}

setuplogdir() {
  mkdir $TESTTMP/logs
  chmod 0755 $TESTTMP/logs
  chmod +t $TESTTMP/logs
}

debugsshcall() {
  sed -n '/^running .*dummyssh.*$/p'
}
