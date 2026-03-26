
#require no-eden


  $ export HGIDENTITY=sl
  $ enable remotefilelog

  $ newrepo foo
  $ echo remotefilelog >> .sl/requires

  $ echo a > a
  $ sl commit -qAm init

Make sure merge state is cleared when we have a clean tree.
  $ mkdir .sl/merge

    # Write out some valid contents
    with open(f"foo/.sl/merge/state2", "bw") as f:
        f.write(b"L\x00\x00\x00\x28")
        f.write(b"a" * 40)

  $ sl debugmergestate
  local: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  $ sl up -qC . --config experimental.nativecheckout=True
  $ sl debugmergestate
  no merge state found
