#require symlink execbit no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ setconfig commands.update.check=none
  $ tellmeabout() {
  >   f -Dxt "$@"
  > }

  $ sl init test1
  $ cd test1

  $ echo a > a
  $ sl ci -Aqmadd
  $ chmod +x a
  $ sl ci -mexecutable

  $ sl up -q 'desc(add)'
  $ rm a
  $ ln -s symlink a
  $ sl ci -msymlink

Symlink is local parent, executable is other:

  $ sl merge --debug
  resolving manifests
   branchmerge: True, force: False
   ancestor: c334dc3be0da, local: 521a1e40188f+, remote: 3574f3e69b1c
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() hgmerge internal:merge
  picked tool ':merge' for path=a binary=False symlink=True changedelete=False
  merging a
  my a@521a1e40188f+ other a@3574f3e69b1c ancestor a@c334dc3be0da
  warning: internal :merge cannot merge symlinks for a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

  $ tellmeabout a
  a -> symlink: link
  $ sl resolve a --tool internal:other
  (no more unresolved files)
  $ tellmeabout a
  a: file, exe
  >>>
  a
  <<<
  $ sl st
  M a
  ? a.orig

Symlink is other parent, executable is local:

  $ sl goto -C 'desc(executable)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl merge --debug --tool :union
  resolving manifests
   branchmerge: True, force: False
   ancestor: c334dc3be0da, local: 3574f3e69b1c+, remote: 521a1e40188f
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() forcemerge toolpath :union
  picked tool ':union' for path=a binary=False symlink=True changedelete=False
  merging a
  my a@3574f3e69b1c+ other a@521a1e40188f ancestor a@c334dc3be0da
  warning: internal :union cannot merge symlinks for a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

  $ tellmeabout a
  a: file, exe
  >>>
  a
  <<<

  $ sl goto -C 'desc(executable)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl merge --debug --tool :merge3
  resolving manifests
   branchmerge: True, force: False
   ancestor: c334dc3be0da, local: 3574f3e69b1c+, remote: 521a1e40188f
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() forcemerge toolpath :merge3
  picked tool ':merge3' for path=a binary=False symlink=True changedelete=False
  merging a
  my a@3574f3e69b1c+ other a@521a1e40188f ancestor a@c334dc3be0da
  warning: internal :merge3 cannot merge symlinks for a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

  $ tellmeabout a
  a: file, exe
  >>>
  a
  <<<

  $ sl goto -C 'desc(executable)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl merge --debug --tool :merge-local
  resolving manifests
   branchmerge: True, force: False
   ancestor: c334dc3be0da, local: 3574f3e69b1c+, remote: 521a1e40188f
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() forcemerge toolpath :merge-local
  picked tool ':merge-local' for path=a binary=False symlink=True changedelete=False
  merging a
  my a@3574f3e69b1c+ other a@521a1e40188f ancestor a@c334dc3be0da
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ tellmeabout a
  a: file, exe
  >>>
  a
  <<<

  $ sl goto -C 'desc(executable)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ sl merge --debug --tool :merge-other
  resolving manifests
   branchmerge: True, force: False
   ancestor: c334dc3be0da, local: 3574f3e69b1c+, remote: 521a1e40188f
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() forcemerge toolpath :merge-other
  picked tool ':merge-other' for path=a binary=False symlink=True changedelete=False
  merging a
  my a@3574f3e69b1c+ other a@521a1e40188f ancestor a@c334dc3be0da
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)

  $ tellmeabout a
  a -> symlink: link

Update to link without local change should get us a symlink (issue3316):

  $ sl up -C 'desc(add)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl up 'desc(symlink)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl st

Update to link with local change should cause a merge prompt (issue3200):

  $ sl up -Cq 'desc(add)'
  $ echo data > a
  $ HGMERGE= sl up -y --debug 'desc(symlink)'
  resolving manifests
   branchmerge: False, force: False
   ancestor: c334dc3be0da, local: c334dc3be0da+, remote: 521a1e40188f
   preserving a for resolve of a
   a: versions differ -> m (premerge)
  picktool() interactive=False plain=False
  (couldn't find merge tool hgmerge|tool hgmerge can't handle symlinks) (re)
  no tool found to merge a
  picked tool ':prompt' for path=a binary=False symlink=True changedelete=False
  keep (l)ocal [working copy], take (o)ther [destination], or leave (u)nresolved for a? u
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges
  [1]
  $ sl diff --git
  diff --git a/a b/a
  old mode 120000
  new mode 100644
  --- a/a
  +++ b/a
  @@ -1,1 +1,1 @@
  -symlink
  \ No newline at end of file
  +data


Test only 'l' change - happens rarely, except when recovering from situations
where that was what happened.

  $ sl init test2
  $ cd test2
  $ printf base > f
  $ sl ci -Aqm0
  $ echo file > f
  $ echo content >> f
  $ sl ci -qm1
  $ sl up -qr'desc(0)'
  $ rm f
  $ ln -s base f
  $ sl ci -qm2
  $ sl merge
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ tellmeabout f
  f -> base: link

  $ sl up -Cqr'desc(1)'
  $ sl merge
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ tellmeabout f
  f: file
  >>>
  file
  content
  <<<

  $ cd ..

Test removed 'x' flag merged with change to symlink

  $ sl init test3
  $ cd test3
  $ echo f > f
  $ chmod +x f
  $ sl ci -Aqm0
  $ chmod -x f
  $ sl ci -qm1
  $ sl up -qr'desc(0)'
  $ rm f
  $ ln -s dangling f
  $ sl ci -qm2
  $ sl merge
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ tellmeabout f
  f -> dangling: link

  $ sl up -Cqr'desc(1)'
  $ sl merge
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ tellmeabout f
  f: file
  >>>
  f
  <<<

Test removed 'x' flag merged with content change - both ways

  $ sl up -Cqr'desc(0)'
  $ echo change > f
  $ sl ci -qm3
  $ sl merge -r'desc(1)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ tellmeabout f
  f: file
  >>>
  change
  <<<

  $ sl up -qCr'desc(1)'
  $ sl merge -r'desc(3)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ tellmeabout f
  f: file
  >>>
  change
  <<<

  $ cd ..

Test merge with no common ancestor:
a: just different
b: x vs -, different (cannot calculate x, cannot ask merge tool)
c: x vs -, same (cannot calculate x, merge tool is no good)
d: x vs l, different
e: x vs l, same
f: - vs l, different
g: - vs l, same
h: l vs l, different
(where same means the filelog entry is shared and there thus is an ancestor!)

  $ sl init test4
  $ cd test4
  $ echo 0 > 0
  $ sl ci -Aqm0

  $ echo 1 > a
  $ echo 1 > b
  $ chmod +x b
  $ echo 1 > bx
  $ chmod +x bx
  $ echo x > c
  $ chmod +x c
  $ echo 1 > d
  $ chmod +x d
  $ printf x > e
  $ chmod +x e
  $ echo 1 > f
  $ printf x > g
  $ ln -s 1 h
  $ sl ci -qAm1

  $ sl up -qr'desc(0)'
  $ echo 2 > a
  $ echo 2 > b
  $ echo 2 > bx
  $ chmod +x bx
  $ echo x > c
  $ ln -s 2 d
  $ ln -s x e
  $ ln -s 2 f
  $ ln -s x g
  $ ln -s 2 h
  $ sl ci -Aqm2

  $ sl merge
  merging a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  warning: cannot merge flags for b without common ancestor - keeping local flags
  merging b
  warning: 1 conflicts while merging b! (edit, then use 'sl resolve --mark')
  merging bx
  warning: 1 conflicts while merging bx! (edit, then use 'sl resolve --mark')
  warning: cannot merge flags for c without common ancestor - keeping local flags
  merging d
  warning: internal :merge cannot merge symlinks for d
  warning: 1 conflicts while merging d! (edit, then use 'sl resolve --mark')
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  merging h
  warning: internal :merge cannot merge symlinks for h
  warning: 1 conflicts while merging h! (edit, then use 'sl resolve --mark')
  3 files updated, 0 files merged, 0 files removed, 6 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ sl resolve -l
  U a
  U b
  U bx
  U d
  U f
  U h
  $ tellmeabout a
  a: file
  >>>
  <<<<<<< working copy: 0c617753b41b - test: 2
  2
  =======
  1
  >>>>>>> merge rev:    2e60aa20b912 - test: 1
  <<<
  $ tellmeabout b
  b: file
  >>>
  <<<<<<< working copy: 0c617753b41b - test: 2
  2
  =======
  1
  >>>>>>> merge rev:    2e60aa20b912 - test: 1
  <<<
  $ tellmeabout c
  c: file
  >>>
  x
  <<<
  $ tellmeabout d
  d -> 2: link
  $ tellmeabout e
  e -> x: link
  $ tellmeabout f
  f -> 2: link
  $ tellmeabout g
  g -> x: link
  $ tellmeabout h
  h -> 2: link

  $ sl up -Cqr'desc(1)'
  $ sl merge
  merging a
  warning: 1 conflicts while merging a! (edit, then use 'sl resolve --mark')
  warning: cannot merge flags for b without common ancestor - keeping local flags
  merging b
  warning: 1 conflicts while merging b! (edit, then use 'sl resolve --mark')
  merging bx
  warning: 1 conflicts while merging bx! (edit, then use 'sl resolve --mark')
  warning: cannot merge flags for c without common ancestor - keeping local flags
  merging d
  warning: internal :merge cannot merge symlinks for d
  warning: 1 conflicts while merging d! (edit, then use 'sl resolve --mark')
  merging f
  warning: internal :merge cannot merge symlinks for f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  merging h
  warning: internal :merge cannot merge symlinks for h
  warning: 1 conflicts while merging h! (edit, then use 'sl resolve --mark')
  3 files updated, 0 files merged, 0 files removed, 6 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ tellmeabout a
  a: file
  >>>
  <<<<<<< working copy: 2e60aa20b912 - test: 1
  1
  =======
  2
  >>>>>>> merge rev:    0c617753b41b - test: 2
  <<<
  $ tellmeabout b
  b: file, exe
  >>>
  <<<<<<< working copy: 2e60aa20b912 - test: 1
  1
  =======
  2
  >>>>>>> merge rev:    0c617753b41b - test: 2
  <<<
  $ tellmeabout c
  c: file, exe
  >>>
  x
  <<<
  $ tellmeabout d
  d: file, exe
  >>>
  1
  <<<
  $ tellmeabout e
  e: file, exe
  >>>
  x
  <<< no trailing newline
  $ tellmeabout f
  f: file
  >>>
  1
  <<<
  $ tellmeabout g
  g: file
  >>>
  x
  <<< no trailing newline
  $ tellmeabout h
  h -> 1: link

  $ cd ..


Make sure we don't merge symlinks:
  $ newrepo
  $ drawdag <<EOS
  > B   # B/link = foo\ntwo\nthree (symlink)
  > |
  > | C # C/link = one\ntwo\nbar (symlink)
  > |/
  > A   # A/link = one\ntwo\nthree (symlink)
  $ sl go -q $B
  $ sl merge -q --tool :merge-other
  $ tellmeabout link
  link -> one
  two
  bar: link

  $ sl go -qC $B
  $ sl merge -q --tool :merge-local
  $ tellmeabout link
  link -> foo
  two
  three: link
