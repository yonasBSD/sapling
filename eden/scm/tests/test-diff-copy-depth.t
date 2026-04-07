
#require no-eden


  $ eagerepo

  $ for i in aaa zzz; do
  >     newclientrepo
  > 
  >     echo
  >     echo "-- With $i"
  > 
  >     touch file
  >     sl add file
  >     sl ci -m "Add"
  > 
  >     sl cp file $i
  >     sl ci -m "a -> $i"
  > 
  >     sl cp $i other-file
  >     echo "different" >> $i
  >     sl ci -m "$i -> other-file"
  > 
  >     sl cp other-file somename
  > 
  >     echo "Status":
  >     sl st -C
  >     echo
  >     echo "Diff:"
  >     sl diff -g
  > 
  >     cd ..
  >     rm -rf t
  > done
  
  -- With aaa
  Status:
  A somename
    other-file
  
  Diff:
  diff --git a/other-file b/somename
  copy from other-file
  copy to somename
  
  -- With zzz
  Status:
  A somename
    other-file
  
  Diff:
  diff --git a/other-file b/somename
  copy from other-file
  copy to somename


