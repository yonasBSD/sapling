
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ enable blackbox rage smartlog sparse share

  $ sl init repo
  $ cd repo
#if osx
  $ echo "[rage]" >> .sl/config
  $ echo "rpmbin = /""bin/rpm" >> .sl/config
#endif
  $ sl rage --preview > out.txt
  $ cat out.txt | grep -o '^hg blackbox'
  hg blackbox
  $ cat out.txt | grep -o '^hg cloud status'
  hg cloud status
  $ cat out.txt | grep -o '^hg sparse:'
  hg sparse:
  $ rm out.txt

Test with shared repo
  $ cd ..
  $ sl share repo repo2
  updating working directory
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

Create fake backedupheads state to be collected by rage

  $ mkdir repo/.sl/commitcloud
  $ echo '"fakestate": "something"' > repo/.sl/commitcloud/backedupheads.abc
  $ cd repo2
  $ sl rage --preview | grep [f]akestate
  "fakestate": "something"

  $ cd ..

Create fake commit cloud  state to be collected by rage

  $ echo '{ "commit_cloud_workspace": "something" }' > repo/.sl/store/commitcloudstate.someamazingworkspace.json
  $ cd repo2
  $ sl rage --preview | grep [c]ommit_cloud_workspace
      "commit_cloud_workspace": "something"

  $ cd ..

Redact sensitive data

  $ cd repo
  $ echo 'hi' > file.txt
  $ sl commit -A -m "leaking a secret: access_token: a1b2c3d4f4f6, oh no!"
  adding file.txt
  $ sl rage --preview | grep "access_token: a1b2c3d4f4f6"
  [1]
