
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ . "$TESTDIR/histedit-helpers.sh"

  $ enable fbhistedit histedit rebase

  $ addcommits ()
  > {
  >     for x in "$@" ; do
  >         echo "$x" > "$x"
  >         sl add "$x"
  >         sl ci -m "$x"
  >     done
  > }
  $ initrepo ()
  > {
  >     sl init r
  >     cd r
  >     addcommits a b c d e f
  >     sl goto 'desc(b)'
  >     addcommits g h i
  >     sl goto 'desc(b)'
  >     echo CONFLICT > f
  >     sl add f
  >     sl ci -m "conflict f"
  > }

  $ initrepo
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved

log before rebase

  $ sl log -G -T '{node|short} {desc|firstline}\n'
  @  8d0611d6e5f2 conflict f
  │
  │ o  cf7e1bc6a982 i
  │ │
  │ o  7523912c6e49 h
  │ │
  │ o  0ba40a7dd69a g
  ├─╯
  │ o  652413bf663e f
  │ │
  │ o  e860deea161a e
  │ │
  │ o  055a42cdd887 d
  │ │
  │ o  177f92b77385 c
  ├─╯
  o  d2ae7f538514 b
  │
  o  cb9a9f314b8b a
  
Simple rebase with -s and -d

  $ sl goto cf7e1bc6a982390237dd47e096c15bca92fe2237
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ HGEDITOR=true sl rebase -i -s cf7e1bc6a982390237dd47e096c15bca92fe2237 -d 652413bf663ef2a641cab26574e46d5f5a64a55a

  $ sl log -G -T '{node|short} {desc|firstline}\n'
  @  bb8affa27bd8 i
  │
  │ o  8d0611d6e5f2 conflict f
  │ │
  │ │ o  7523912c6e49 h
  │ │ │
  │ │ o  0ba40a7dd69a g
  │ ├─╯
  o │  652413bf663e f
  │ │
  o │  e860deea161a e
  │ │
  o │  055a42cdd887 d
  │ │
  o │  177f92b77385 c
  ├─╯
  o  d2ae7f538514 b
  │
  o  cb9a9f314b8b a
  

Try to rebase with conflict (also check -d without -s)
  $ sl goto 'desc("conflict f")'
  1 files updated, 0 files merged, 4 files removed, 0 files unresolved

  $ HGEDITOR=true sl rebase -i -d 'desc(i)'
  merging f
  warning: 1 conflicts while merging f! (edit, then use 'sl resolve --mark')
  Fix up the change (pick 8d0611d6e5f2)
  (sl histedit --continue to resume)
  [1]

  $ echo resolved > f
  $ sl resolve --mark f
  (no more unresolved files)
  continue: sl histedit --continue
  $ sl histedit --continue

  $ sl log -G -T '{node|short} {desc|firstline}\n'
  @  b6ca70f8129d conflict f
  │
  o  bb8affa27bd8 i
  │
  │ o  7523912c6e49 h
  │ │
  │ o  0ba40a7dd69a g
  │ │
  o │  652413bf663e f
  │ │
  o │  e860deea161a e
  │ │
  o │  055a42cdd887 d
  │ │
  o │  177f92b77385 c
  ├─╯
  o  d2ae7f538514 b
  │
  o  cb9a9f314b8b a
  

Rebase with base
  $ sl goto 'desc(h)'
  2 files updated, 0 files merged, 5 files removed, 0 files unresolved
  $ HGEDITOR=true sl rebase -i -b . -d 'desc(conflict)'
  $ sl log -G -T '{node|short} {desc|firstline}\n'
  @  50cf975d06ef h
  │
  o  ba6932766227 g
  │
  o  b6ca70f8129d conflict f
  │
  o  bb8affa27bd8 i
  │
  o  652413bf663e f
  │
  o  e860deea161a e
  │
  o  055a42cdd887 d
  │
  o  177f92b77385 c
  │
  o  d2ae7f538514 b
  │
  o  cb9a9f314b8b a
  
Rebase with -s and -d and checked out to something that is not a child of
either the source or destination.  This unfortunately is rejected since the
histedit code currently requires all edited commits to be ancestors of the
current working directory parent.

  $ sl goto 'desc(i) - desc(conflict)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ addcommits x y z
  $ sl goto 'desc(f) - desc(conflict)'
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ sl log -G -T '{node|short} {desc|firstline}\n'
  o  70ff95fe5c79 z
  │
  o  9843e524084d y
  │
  o  a5ae87083656 x
  │
  │ o  50cf975d06ef h
  │ │
  │ o  ba6932766227 g
  │ │
  │ o  b6ca70f8129d conflict f
  ├─╯
  o  bb8affa27bd8 i
  │
  @  652413bf663e f
  │
  o  e860deea161a e
  │
  o  055a42cdd887 d
  │
  o  177f92b77385 c
  │
  o  d2ae7f538514 b
  │
  o  cb9a9f314b8b a
  
  $ HGEDITOR=true sl rebase -i -s 'desc(y)' -d 'desc(g)'
  abort: source revision (-s) must be an ancestor of the working directory for interactive rebase
  [255]
