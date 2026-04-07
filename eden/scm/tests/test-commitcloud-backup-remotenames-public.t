#modern-config-incompatible

#require no-eden

#inprocess-hg-incompatible


Remotenames extension has a shortcut that makes heads discovery work faster.
Unfortunately that may result in sending public commits to the server. This
test covers the issue.

  $ . $TESTDIR/library.sh
  $ . $TESTDIR/infinitepush/library.sh

  $ setupcommon

  $ mkcommit() {
  >    echo "$1" > "$1"
  >    sl add "$1"
  >    sl ci -m "$1"
  > }
  $ scratchnodes() {
  >    for node in `find ../repo/.sl/scratchbranches/index/nodemap/* | sort`; do
  >        echo ${node##*/}
  >    done
  > }
  $ scratchbookmarks() {
  >    for bookmark in `find ../repo/.sl/scratchbranches/index/bookmarkmap/* -type f | sort`; do
  >        echo "${bookmark##*/bookmarkmap/} `cat $bookmark`"
  >    done
  > }

Setup server with a few commits and one remote bookmark.
  $ sl init repo
  $ cd repo
  $ setupserver
  $ mkcommit first
  $ sl book remotebook
  $ sl up -q .
  $ mkcommit second
  $ mkcommit third
  $ mkcommit fourth
  $ sl bookmark master
  $ cd ..

Create new client
  $ sl clone ssh://user@dummy/repo client -q
  $ cd client

Create scratch commit and back it up.
  $ sl up -q -r 'desc(third)'
  $ mkcommit scratch
  $ sl log -r . -T '{node}\n'
  ce87a066ebc28045311cd1272f5edc0ed80d5b1c
  $ sl log --graph -T '{desc}'
  @  scratch
  │
  │ o  fourth
  ├─╯
  o  third
  │
  o  second
  │
  o  first
  
  $ sl cloud backup
  commitcloud: head 'ce87a066ebc2' hasn't been uploaded yet
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
  $ cd ..

Create second client
  $ sl clone ssh://user@dummy/repo client2 -q
  $ cd client2

Pull to get remote names
  $ sl pull
  pulling from ssh://user@dummy/repo
  $ sl book --remote
     remote/master                    05fb75d88dcd1fd5bb73daffe4142774c5aa5547
     remote/remotebook                b75a450e74d5a7708da8c3144fbeb4ac88694044

Strip public commits from the repo (still needed?)
  $ sl debugstrip -q -r 'desc(second):'
  $ sl log --graph -T '{desc}'
  @  first
  
Download scratch commit. It also downloads a few public commits
  $ sl up -q ce87a066ebc28045311cd1272f5edc0ed80d5b1c
  $ sl log --graph -T '{desc}'
  @  scratch
  │
  │ o  fourth
  ├─╯
  o  third
  │
  o  second
  │
  o  first
  
  $ sl book --remote
     remote/master                    05fb75d88dcd1fd5bb73daffe4142774c5aa5547
     remote/remotebook                b75a450e74d5a7708da8c3144fbeb4ac88694044

Run cloud backup and make sure only scratch commits are backed up.
  $ sl cloud backup
  commitcloud: nothing to upload
  $ mkcommit scratch2
  $ sl cloud backup
  commitcloud: head '4dbf2c8dd7d9' hasn't been uploaded yet
  edenapi: queue 1 commit for upload
  edenapi: queue 1 file for upload
  edenapi: uploaded 1 file
  edenapi: queue 1 tree for upload
  edenapi: uploaded 1 tree
  edenapi: uploaded 1 changeset
