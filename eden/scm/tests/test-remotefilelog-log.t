#inprocess-hg-incompatible
#require mononoke
#modern-config-incompatible

  $ . "$TESTDIR/library.sh"

  $ newserver master_bookmark
  $ clone master_bookmark client1
  $ cd client1
  $ echo x > x
  $ sl commit -qAm x
  $ mkdir dir
  $ echo y > dir/y
  $ sl commit -qAm y
  $ sl push -r tip --to master_bookmark --create --config paths.default=mononoke://$(mononoke_address)/master_bookmark
  remote: adding changesets (?)
  remote: adding manifests (?)
  remote: adding file changes (?)
  pushing rev 79c51fb96423 to destination mononoke://$LOCALIP:$LOCAL_PORT/master_bookmark bookmark master_bookmark
  searching for changes
  exporting bookmark master_bookmark

  $ cd ..

Shallow clone from full

  $ clone master_bookmark shallow --noupdate
  $ cd shallow
  $ cat .sl/requires
  generaldelta
  remotefilelog
  revlogv1
  store
  treestate
  windowssymlinks

  $ sl goto tip
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

Log on a file without -f

  $ sl log dir/y
  warning: file log can be slow on large repos - use -f to speed it up
  commit:      79c51fb96423
  bookmark:    remote/master_bookmark
  hoistedname: master_bookmark
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  
Log on a file with -f

  $ sl log -f dir/y
  commit:      79c51fb96423
  bookmark:    remote/master_bookmark
  hoistedname: master_bookmark
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  
Log on a file with kind in path
  $ sl log -r "filelog('path:dir/y')"
FIXME: enable selective pull
Output used to be not empty

Log on multiple files with -f

  $ sl log -f dir/y x
  commit:      79c51fb96423
  bookmark:    remote/master_bookmark
  hoistedname: master_bookmark
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  
  commit:      b292c1e3311f
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     x
  
Log on a directory

  $ sl log dir
  commit:      79c51fb96423
  bookmark:    remote/master_bookmark
  hoistedname: master_bookmark
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  
Log on a file from inside a directory

  $ cd dir
  $ sl log y
  warning: file log can be slow on large repos - use -f to speed it up
  commit:      79c51fb96423
  bookmark:    remote/master_bookmark
  hoistedname: master_bookmark
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     y
  
Log on a file via -fr
  $ cd ..
  $ sl log -fr tip dir/ --template '{node}\n'
  79c51fb9642383579314de1dcd88e4dd7b1b518a

Trace renames
  $ echo >> x
  $ sl commit -m "Edit x"
  $ sl mv x z
  $ sl commit -m move
  $ sl log -f z -T '{desc}\n' -G --pager=off
  @  move
  │
  o  Edit x
  ╷
  o  x
  

Verify remotefilelog handles rename metadata stripping when comparing file sizes
  $ sl debugrebuilddirstate
  $ sl status
