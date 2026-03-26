#modern-config-incompatible

#require no-eden


  $ export HGIDENTITY=sl
  $ mkcommit()
  > {
  >    echo $1 > $1
  >    sl add $1
  >    sl ci -m "add $1"
  > }


Test that remotenames works on a repo without any names file

  $ sl init alpha
  $ cd alpha
  $ mkcommit a
  $ mkcommit b
  $ sl book master
  $ sl log -r 'upstream()'
  $ sl log -r . -T '{remotenames} {remotebookmarks}\n'
   

Continue testing

  $ mkcommit c
  $ cd ..
  $ sl clone alpha beta
  updating to tip
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd beta
  $ sl book babar
  $ mkcommit d
  $ cd ..

  $ sl init gamma
  $ cd gamma
  $ echo remotefilelog >> .sl/requires
  $ cat > .sl/config <<EOF
  > [paths]
  > default = ../alpha
  > alpha = ../alpha
  > beta = ../beta
  > [remotenames]
  > selectivepulldefault=babar
  > EOF
  $ sl pull -q beta
  $ sl co -C default
  4 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ mkcommit e

graph shows tags for the branch heads of each path
  $ sl log --graph
  @  commit:      9d206ffc875e
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add e
  │
  o  commit:      47d2a3944de8
  │  bookmark:    beta/babar
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add d
  │
  o  commit:      4538525df7e2
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add c
  │
  o  commit:      7c3bad9141dc
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add b
  │
  o  commit:      1f0dee641bb7
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  

make sure we can list remote bookmarks with --all

  $ sl bookmarks --all
  no bookmarks set
     beta/babar                47d2a3944de8

  $ sl bookmarks --all -T json
  [
   {
    "node": "47d2a3944de8b013de3be9578e8e344ea2e6c097",
    "remotebookmark": "beta/babar"
   }
  ]
  $ sl bookmarks --remote
     remote/master                    4538525df7e2b9f09423636c61ef63a4cb872a2d

Verify missing node doesnt break remotenames

  $ sl dbsh << 'EOS'
  > ml["remotenames"] = ml["remotenames"] + b"18f8e0f8ba54270bf158734c781327581cf43634 bookmarks beta/foo\n"
  > ml.commit("add unknown ref to remotenames")
  > EOS
  $ sl book --remote
     remote/master                    4538525df7e2b9f09423636c61ef63a4cb872a2d

make sure bogus revisions in .sl/store/remotenames do not break hg
  $ echo deadbeefdeadbeefdeadbeefdeadbeefdeadbeef default/default >> \
  > .sl/store/remotenames
  $ sl parents
  commit:      9d206ffc875e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add e
  
Verify that the revsets operate as expected:
  $ sl log -r 'not pushed()'
  commit:      9d206ffc875e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add e
  


Upstream without configuration is synonymous with upstream('default'):
  $ sl log -r 'not upstream()'
  commit:      1f0dee641bb7
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add a
  
  commit:      7c3bad9141dc
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add b
  
  commit:      4538525df7e2
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add c
  
  commit:      47d2a3944de8
  bookmark:    beta/babar
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add d
  
  commit:      9d206ffc875e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     add e
  

but configured, it'll do the expected thing:
  $ echo '[remotenames]' >> .sl/config
  $ echo 'upstream=alpha' >> .sl/config
  $ sl log --graph -r 'not upstream()'
  @  commit:      9d206ffc875e
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add e
  │
  o  commit:      47d2a3944de8
  │  bookmark:    beta/babar
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add d
  │
  o  commit:      4538525df7e2
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add c
  │
  o  commit:      7c3bad9141dc
  │  user:        test
  │  date:        Thu Jan 01 00:00:00 1970 +0000
  │  summary:     add b
  │
  o  commit:      1f0dee641bb7
     user:        test
     date:        Thu Jan 01 00:00:00 1970 +0000
     summary:     add a
  
  $ sl log --limit 2 --graph -r 'heads(upstream())'

Test remotenames revset and keyword

  $ sl log -r 'remotenames()' \
  >   --template '{node|short} {remotenames}\n'
  47d2a3944de8 beta/babar

Test remotebookmark revsets

  $ sl log -r 'remotebookmark()' \
  >   --template '{node|short} {remotebookmarks}\n'
  47d2a3944de8 beta/babar
  $ sl log -r 'remotebookmark("beta/babar")' \
  >   --template '{node|short} {remotebookmarks}\n'
  47d2a3944de8 beta/babar
  $ sl log -r 'remotebookmark("beta/stable")' \
  >   --template '{node|short} {remotebookmarks}\n'
  abort: no remote bookmarks exist that match 'beta/stable'!
  [255]
  $ sl log -r 'remotebookmark("re:beta/.*")' \
  >   --template '{node|short} {remotebookmarks}\n'
  47d2a3944de8 beta/babar
  $ sl log -r 'remotebookmark("re:gamma/.*")' \
  >   --template '{node|short} {remotebookmarks}\n'
  abort: no remote bookmarks exist that match 're:gamma/.*'!
  [255]


Test custom paths dont override default
  $ cd ..
  $ cd alpha
  $ sl book foo bar baz
  $ cd ..
  $ sl init path_overrides
  $ cd path_overrides
  $ sl path -a default ../alpha
  $ sl path -a custom ../alpha
  $ sl pull -q
  $ sl book --remote
     remote/bar                       4538525df7e2b9f09423636c61ef63a4cb872a2d
     remote/baz                       4538525df7e2b9f09423636c61ef63a4cb872a2d
     remote/foo                       4538525df7e2b9f09423636c61ef63a4cb872a2d
     remote/master                    4538525df7e2b9f09423636c61ef63a4cb872a2d


Test json formatted bookmarks with tracking data
  $ cd ..
  $ sl init delta
  $ cd delta
  $ sl book mimimi -t lalala
  $ sl book -v -T json
  [
   {
    "active": true,
    "bookmark": "mimimi",
    "node": "0000000000000000000000000000000000000000",
    "tracking": "lalala"
   }
  ]
  $ sl book -v
   * mimimi                    000000000000           [lalala]
