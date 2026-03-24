
  $ export HGIDENTITY=sl
  $ addcommit () {
  >     echo $1 > $1
  >     sl add $1
  >     sl commit -d "${2} 0" -m $1
  > }

  $ commit () {
  >     sl commit -d "${2} 0" -m $1
  > }

  $ newclientrepo a
  $ addcommit "A" 0
  $ addcommit "B" 1
  $ echo "C" >> A
  $ commit "C" 2

  $ sl goto -C 'desc(A)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "D" >> A
  $ commit "D" 3

Merging a conflict araises

  $ sl merge
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]

Correct the conflict without marking the file as resolved

  $ echo "ABCD" > A
  $ sl commit -m "Merged"
  abort: unresolved merge state
  (use 'sl resolve' to continue or
       'sl goto --clean' to abort - WARNING: will destroy uncommitted changes)
  [255]

Mark the conflict as resolved and commit

  $ sl resolve -m A
  (no more unresolved files)
  $ sl commit -m "Merged"

Test that if a file is removed but not marked resolved, the commit still fails
(issue4972)

  $ sl up ".^"
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl merge 'desc(C)'
  merging A
  warning: 1 conflicts while merging A! (edit, then use 'sl resolve --mark')
  1 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'sl resolve' to retry unresolved file merges or 'sl goto -C .' to abandon
  [1]
  $ sl rm --force A
  $ sl commit -m merged
  abort: unresolved merge state
  (use 'sl resolve' to continue or
       'sl goto --clean' to abort - WARNING: will destroy uncommitted changes)
  [255]

  $ sl resolve -ma
  (no more unresolved files)
  $ sl commit -m merged

  $ cd ..
