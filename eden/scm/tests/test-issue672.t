
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
https://bz.mercurial-scm.org/672

# 0-2-4
#  \ \ \
#   1-3-5
#
# rename in #1, content change in #4.

  $ sl init repo
  $ cd repo

  $ touch 1
  $ touch 2
  $ sl commit -Am init  # 0
  adding 1
  adding 2

  $ sl rename 1 1a
  $ sl commit -m rename # 1

  $ sl co -C 'desc(init)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ echo unrelated >> 2
  $ sl ci -m unrelated1 # 2

  $ sl merge --debug 'desc(rename)'
  resolving manifests
   branchmerge: True, force: False
   ancestor: 81f4b099af3d, local: c64f439569a9+, remote: c12dcd37c90a
   preserving 1 for resolve of 1a
  removing 1
   1a: remote moved from 1 -> g
  getting 1a
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl ci -m merge1 # 3

  $ sl co -C 'desc(unrelated1)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ echo hello >> 1
  $ sl ci -m unrelated2 # 4

  $ sl co -C 'desc(merge1)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ sl log -G -T '{node|short} {desc}'
  o  746e9549ea96 unrelated2
  │
  │ @  7aff4c906f45 merge1
  ╭─┤
  o │  c64f439569a9 unrelated1
  │ │
  │ o  c12dcd37c90a rename
  ├─╯
  o  81f4b099af3d init
  $ sl log -r 'p1(7aff4c906f45)' -T '{node|short} {desc}\n'
  c64f439569a9 unrelated1

# dagcopytrace does not support merge commits (it only searches p1)

  $ sl merge -y --debug 'desc(unrelated2)'
  resolving manifests
   branchmerge: True, force: False
   ancestor: c64f439569a9, local: 7aff4c906f45+, remote: 746e9549ea96
   1: prompt deleted/changed -> m (premerge)
  picktool() hgmerge :prompt internal:merge
  picked tool ':prompt' for path=1 binary=False symlink=False changedelete=True
  other [merge rev] changed 1 which local [working copy] is missing
  hint: if this is due to a renamed file, you can manually input the renamed path
  use (c)hanged version, leave (d)eleted, or leave (u)nresolved, or input (r)enamed path? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

# dagcopytrace does not support merge commits (it only searches p1)

  $ sl co -C 'desc(unrelated2)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ sl merge -y --debug 'desc(merge1)'
  resolving manifests
   branchmerge: True, force: False
   ancestor: c64f439569a9, local: 746e9549ea96+, remote: 7aff4c906f45
   preserving 1 for resolve of 1
   1a: remote created -> g
  getting 1a
   1: prompt changed/deleted -> m (premerge)
  picktool() hgmerge :prompt internal:merge
  picked tool ':prompt' for path=1 binary=False symlink=False changedelete=True
  local [working copy] changed 1 which other [merge rev] deleted
  use (c)hanged version, (d)elete, or leave (u)nresolved? u
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
