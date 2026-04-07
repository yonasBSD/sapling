#modern-config-incompatible

#require no-eden

#inprocess-hg-incompatible


  $ configure dummyssh
  $ enable rebase

  $ sl init master
  $ cd master
  $ echo a >> a && sl ci -Aqm a
  $ sl book master
  $ sl book -i
  $ echo b >> b && sl ci -Aqm b
  $ sl book foo

  $ cd ..
  $ sl clone -q ssh://user@dummy/master client -u 0

Verify pulling only some commits does not cause errors from the unpulled
remotenames
  $ cd client
  $ sl pull -r 0
  pulling from ssh://user@dummy/master
  $ sl book --remote
     remote/foo                       d2ae7f538514cd87c17547b0de4cea71fe1af9fb
     remote/master                    cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b
  $ sl dbsh -c 'ui.write(repo.svfs.readutf8("remotenames"))'
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b bookmarks remote/master

  $ sl pull --rebase -d master
  pulling from ssh://user@dummy/master
  nothing to rebase - working directory parent is also destination
