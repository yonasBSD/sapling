
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
  $ sl init repo
  $ cd repo
  $ enable sparse rebase

  $ sl debugdrawdag <<'EOS'
  >   D
  >   |
  > B C
  > |/
  > A
  > EOS

  $ sl sparse --exclude A B C D E
  $ sl goto A -q
  $ printf D > D
  $ echo 2 > E
  $ sl rebase -s C -d B
  rebasing dc0947a82db8 "C" (C)
  temporarily included 1 file(s) in the sparse checkout for merging
  cleaned up 1 temporarily added file(s) from the sparse checkout
  rebasing e7b3f00ed42e "D" (D)
  temporarily included 1 file(s) in the sparse checkout for merging
  cleaned up 1 temporarily added file(s) from the sparse checkout
