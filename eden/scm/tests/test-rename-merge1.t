
#require no-eden


  $ export HGIDENTITY=sl
  $ newclientrepo

  $ setconfig merge.followcopies=1

  $ echo foo > a
  $ echo foo > a2
  $ sl add a a2
  $ sl ci -m "start"

  $ sl mv a b
  $ sl mv a2 b2
  $ sl ci -m "rename"

  $ sl co 'desc(start)'
  2 files updated, 0 files merged, 2 files removed, 0 files unresolved

  $ echo blahblah > a
  $ echo blahblah > a2
  $ sl mv a2 c2
  $ sl ci -m "modify"

  $ sl merge -y --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: af1939970a1c, local: 044f8520aeeb+, remote: 85c198ef2f6c
   preserving a for resolve of b
  removing a
   b: remote moved from a -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=b binary=False symlink=False changedelete=False
  merging a and b to b
  my b@044f8520aeeb+ other b@85c198ef2f6c ancestor a@af1939970a1c
  1 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ sl status -AC
  M b
    a
  M b2
  R a
  C c2

  $ cat b
  blahblah

  $ sl ci -m "merge"

  $ sl debugrename b
  b renamed from a:dd03b83622e78778b403775d0d074b9ac7387a66

This used to trigger a "divergent renames" warning, despite no renames

  $ sl cp b b3
  $ sl cp b b4
  $ sl ci -A -m 'copy b twice'
  $ sl up eb92d88a9712
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl up tip
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl rm b3 b4
  $ sl ci -m 'clean up a bit of our mess'

We'd rather not warn on divergent renames done in the same changeset (issue2113)

  $ sl cp b b3
  $ sl mv b b4
  $ sl ci -A -m 'divergent renames in same changeset'
  $ sl up c761c6948de0
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl up tip
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved

Check for issue2642

  $ newclientrepo

  $ echo c0 > f1
  $ sl ci -Aqm0

  $ sl up null -q
  $ echo c1 > f1 # backport
  $ sl ci -Aqm1
  $ sl mv f1 f2
  $ sl ci -qm2

  $ sl up 'desc(0)' -q
  $ sl merge 'desc(1)' -q --tool internal:local
  $ sl ci -qm3

  $ sl merge 'desc(2)'
  merging f1 and f2 to f2
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f2
  c0

  $ cd ..

Check for issue2089

  $ newclientrepo

  $ echo c0 > f1
  $ sl ci -Aqm0

  $ sl up null -q
  $ echo c1 > f1
  $ sl ci -Aqm1

  $ sl up 'desc(0)' -q
  $ sl merge 'desc(1)' -q --tool internal:local
  $ echo c2 > f1
  $ sl ci -qm2

  $ sl up 'desc(1)' -q
  $ sl mv f1 f2
  $ sl ci -Aqm3

  $ sl up 'desc(2)' -q
  $ sl merge 'desc(3)'
  merging f1 and f2 to f2
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ cat f2
  c2

  $ cd ..

Check for issue3074

  $ newclientrepo
  $ echo foo > file
  $ sl add file
  $ sl commit -m "added file"
  $ sl mv file newfile
  $ sl commit -m "renamed file"
  $ sl goto 'desc(added)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl rm file
  $ sl commit -m "deleted file"
  $ sl merge --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: 19d7f95df299, local: 0084274f6b67+, remote: 5d32493049f0
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl status
  M newfile
  $ cd ..
