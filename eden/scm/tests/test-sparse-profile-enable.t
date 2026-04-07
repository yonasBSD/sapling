
#require no-eden


  $ eagerepo
test sparse

  $ enable sparse rebase
  $ sl init repo
  $ cd repo
  $ mkdir subdir

  $ cat > foo.sparse <<EOF
  > [include]
  > *
  > EOF
  $ cat > subdir/bar.sparse <<EOF
  > [include]
  > *
  > EOF
  $ sl ci -Aqm 'initial'

Sanity check
  $ sl sparse enable foo.sparse
  $ sl sparse
  %include foo.sparse
  [include]
  
  [exclude]
  
  



  $ sl sparse disable foo.sparse

Relative works from root.
  $ sl sparse enable ./foo.sparse
  $ sl sparse
  %include foo.sparse
  [include]
  
  [exclude]
  
  



  $ sl sparse disable foo.sparse

  $ cd subdir

Canonical path works from subdir.
  $ sl sparse enable foo.sparse
  $ sl sparse
  %include foo.sparse
  [include]
  
  [exclude]
  
  



  $ sl sparse disable foo.sparse

Relative path also works
  $ sl sparse enable ../foo.sparse
  $ sl sparse
  %include foo.sparse
  [include]
  
  [exclude]
  
  



  $ sl sparse disable foo.sparse

  $ sl sparse enable bar.sparse
  $ sl sparse
  %include subdir/bar.sparse
  [include]
  
  [exclude]
  
  



  $ sl sparse disable bar.sparse
