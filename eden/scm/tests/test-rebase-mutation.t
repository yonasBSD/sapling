
#require no-eden

#chg-compatible
  $ setconfig devel.segmented-changelog-rev-compat=true

  $ eagerepo
  $ configure mutation-norecord dummyssh
  $ enable rebase amend
  $ setconfig 'hint.ack=amend-restack'
  $ readconfig <<EOF
  > [ui]
  > logtemplate= {node|short} {desc|firstline}{if(obsolete,' {mutation_nodes}')}
  > [templatealias]
  > mutation_nodes = "{join(mutations % '(rewritten using {operation} as {join(successors % \'{node|short}\', \', \')})', ' ')}"
  > EOF

Setup rebase canonical repo

  $ sl init base
  $ cd base

  $ echo A > A
  $ sl commit -Aqm "A"
  $ echo B > B
  $ sl commit -Aqm "B"
  $ echo C > C
  $ sl commit -Aqm "C"
  $ echo D > D
  $ sl commit -Aqm "D"
  $ sl up -q .~3
  $ echo E > E
  $ sl commit -Aqm "E"
  $ sl book E
  $ sl up -q .~1
  $ echo F > F
  $ sl commit -Aqm "F"
  $ sl merge -q E
  $ sl book -d E
  $ echo G > G
  $ sl commit -Aqm "G"
  $ sl up -q .^
  $ echo H > H
  $ sl commit -Aqm "H"
  $ sl log -G
  @  15ed2d917603 H
  │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  │ o  b3325c91a4d9 D
  │ │
  │ o  f838bfaca5c7 C
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ cd ..

simple rebase
---------------------------------

  $ cp -R base simple
  $ cd simple
  $ sl up 'desc(D)'
  3 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl rebase -d 'desc(G)'
  rebasing 27547f69f254 "B"
  rebasing f838bfaca5c7 "C"
  rebasing b3325c91a4d9 "D"
  $ sl log -G
  @  368c138b79d3 D
  │
  o  9c324c92f058 C
  │
  o  de44e5473df9 B
  │
  │ o  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl log --hidden -G
  @  368c138b79d3 D
  │
  o  9c324c92f058 C
  │
  o  de44e5473df9 B
  │
  │ o  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  │ x  b3325c91a4d9 D (rewritten using rebase as 368c138b79d3)
  │ │
  │ x  f838bfaca5c7 C (rewritten using rebase as 9c324c92f058)
  │ │
  │ x  27547f69f254 B (rewritten using rebase as de44e5473df9)
  ├─╯
  o  4a2df7238c3b A
  
  $ sl debugmutation -r ::.
   *  4a2df7238c3b48766b5e22fafbb8a2f506ec8256
  
   *  4e18486b35689011fba83ca295f65cf08ae151cc
  
   *  c137c2b8081f737881d76f4c799a9ab87fb27367
  
   *  3dbfcf9931fb27cdf64b5466a7be8e0455c3de53
  
   *  de44e5473df9c3cff865166cedfe00e61f0c0499 rebase by test at 1970-01-01T00:00:00 from:
      27547f69f25460a52fff66ad004e58da7ad3fb56
  
   *  9c324c92f0588ca753589b8253a81869034278c9 rebase by test at 1970-01-01T00:00:00 from:
      f838bfaca5c7226600ebcfd84f3c3c13a28d3757
  
   *  368c138b79d3a07f9f552551ba189fe65650cfcc rebase by test at 1970-01-01T00:00:00 from:
      b3325c91a4d916bcc4cdc83ea3fe4ece46a42f6e
  

  $ cd ..

empty changeset
---------------------------------

  $ cp -R base empty
  $ cd empty
  $ sl up 'desc(G)'
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved

We make a copy of both the first changeset in the rebased and some other in the
set.

  $ sl graft 'desc(B)' 'desc(D)'
  grafting 27547f69f254 "B"
  grafting b3325c91a4d9 "D"
  $ sl rebase  -s 'min(desc(B))' -d .
  rebasing 27547f69f254 "B"
  note: not rebasing 27547f69f254, its destination (rebasing onto) commit already has all its changes
  rebasing f838bfaca5c7 "C"
  rebasing b3325c91a4d9 "D"
  note: not rebasing b3325c91a4d9, its destination (rebasing onto) commit already has all its changes
  $ sl log -G
  o  47afe0acbe69 C
  │
  @  7feeeb5dcdab D
  │
  o  0f436dd2ef1b B
  │
  │ o  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl log --hidden -G
  o  47afe0acbe69 C
  │
  @  7feeeb5dcdab D
  │
  o  0f436dd2ef1b B
  │
  │ o  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  │ o  b3325c91a4d9 D
  │ │
  │ x  f838bfaca5c7 C (rewritten using rebase as 47afe0acbe69)
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ sl debugmutation -r 'max(desc(C))'
   *  47afe0acbe69fea7534fd9f3a35fab09f9cb53da rebase by test at 1970-01-01T00:00:00 from:
      f838bfaca5c7226600ebcfd84f3c3c13a28d3757
  

More complex case where part of the rebase set were already rebased

  $ sl rebase --rev 'desc(D) & ::.' --dest 'desc(H)'
  rebasing 7feeeb5dcdab "D"
  $ sl debugmutation -r 'max(desc(D))'
   *  7d1575e225fe518e88eaa5b98015c3b3c139151f rebase by test at 1970-01-01T00:00:00 from:
      7feeeb5dcdab46bab5a9ab75849446fdde86bbc6
  
  $ sl log -G
  @  7d1575e225fe D
  │
  │ o  47afe0acbe69 C
  │ │
  │ x  7feeeb5dcdab D (rewritten using rebase as 7d1575e225fe)
  │ │
  │ o  0f436dd2ef1b B
  │ │
  o │  15ed2d917603 H
  │ │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl rebase --source 'desc(B)' --dest 'tip' --config experimental.rebaseskipobsolete=True
  rebasing 0f436dd2ef1b "B"
  note: not rebasing 7feeeb5dcdab "D", already in destination as 7d1575e225fe "D"
  rebasing 47afe0acbe69 "C"
  $ sl debugmutation -r 'max(desc(D))'::'max(desc(C))'
   *  7d1575e225fe518e88eaa5b98015c3b3c139151f rebase by test at 1970-01-01T00:00:00 from:
      7feeeb5dcdab46bab5a9ab75849446fdde86bbc6
  
   *  ff04f97480fc81a8da61385950568d0816c4c941 rebase by test at 1970-01-01T00:00:00 from:
      0f436dd2ef1bd05a757739a277b9205dc91dbc86
  
   *  89a4066d69a567ca3619891f047ef963e89c89bf rebase by test at 1970-01-01T00:00:00 from:
      47afe0acbe69fea7534fd9f3a35fab09f9cb53da rebase by test at 1970-01-01T00:00:00 from:
      f838bfaca5c7226600ebcfd84f3c3c13a28d3757
  
  $ sl log -G
  o  89a4066d69a5 C
  │
  o  ff04f97480fc B
  │
  @  7d1575e225fe D
  │
  o  15ed2d917603 H
  │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl log -r 4596109a6a4328c398bde3a4a3b6737cfade3003
  abort: unknown revision '4596109a6a4328c398bde3a4a3b6737cfade3003'!
  [255]
  $ sl up -qr 'desc(G)'
  $ sl graft 'desc(D)'
  grafting b3325c91a4d9 "D"
  grafting 7feeeb5dcdab "D"
  note: graft of 7feeeb5dcdab created no changes to commit
  grafting 7d1575e225fe "D"
  note: graft of 7d1575e225fe created no changes to commit
  $ sl up -qr 'desc(E)'
  $ sl rebase -s tip -d .
  rebasing 4ea2ed9d476e "D"
  $ sl log -r tip
  957b23adf5c4 D (no-eol)
Start rebase from a commit that is obsolete but not hidden only because it's
a working copy parent. We should be moved back to the starting commit as usual
even though it is hidden (until we're moved there).

  $ sl up 'desc(B)' -q
  $ sl rebase --rev 'max(desc(C))' --dest 'max(desc(D))'
  rebasing 89a4066d69a5 "C"
  $ sl log -G
  o  72d2a808a21e C
  │
  o  957b23adf5c4 D
  │
  │ @  ff04f97480fc B
  │ │
  │ o  7d1575e225fe D
  │ │
  │ o  15ed2d917603 H
  │ │
  │ │ o  3dbfcf9931fb G
  ╭─┬─╯
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  

  $ cd ..

collapse rebase
---------------------------------

  $ cp -R base collapse
  $ cd collapse
  $ sl up 'desc(H)' -q
  $ sl rebase  -s 'desc(B)' -d 'desc(G)' --collapse
  rebasing 27547f69f254 "B"
  rebasing f838bfaca5c7 "C"
  rebasing b3325c91a4d9 "D"
  $ sl log -G
  o  38220e8976c3 Collapsed revision
  │
  │ @  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl log --hidden -G
  o  38220e8976c3 Collapsed revision
  │
  │ @  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  │ x  b3325c91a4d9 D (rewritten using rebase as 38220e8976c3)
  │ │
  │ x  f838bfaca5c7 C (rewritten using rebase as 38220e8976c3)
  │ │
  │ x  27547f69f254 B (rewritten using rebase as 38220e8976c3)
  ├─╯
  o  4a2df7238c3b A
  
  $ sl id --debug -r tip
  38220e8976c3141043fe724fdbf5ba53ef80cd1a
  $ sl debugmutation -r tip
   *  38220e8976c3141043fe724fdbf5ba53ef80cd1a rebase by test at 1970-01-01T00:00:00 from:
      |-  27547f69f25460a52fff66ad004e58da7ad3fb56
      |-  f838bfaca5c7226600ebcfd84f3c3c13a28d3757
      '-  b3325c91a4d916bcc4cdc83ea3fe4ece46a42f6e
  

  $ cd ..

Rebase set has hidden descendants
---------------------------------

We rebase a changeset which has hidden descendants. Hidden changesets must not
be rebased.

  $ cp -R base hidden
  $ cd hidden
  $ sl up -q 'desc(H)'
  $ sl log -G
  @  15ed2d917603 H
  │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  │ o  b3325c91a4d9 D
  │ │
  │ o  f838bfaca5c7 C
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ sl rebase -s 'desc(C)' -d 'desc(G)'
  rebasing f838bfaca5c7 "C"
  rebasing b3325c91a4d9 "D"
  $ sl log -G
  o  b9a00f7e0244 D
  │
  o  6c4492b9afc0 C
  │
  │ @  15ed2d917603 H
  │ │
  o │  3dbfcf9931fb G
  ├─╮
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ sl rebase -s 'desc(B)' -d 'desc(H)'
  rebasing 27547f69f254 "B"
  $ sl log -G
  o  6513e8468c61 B
  │
  │ o  b9a00f7e0244 D
  │ │
  │ o  6c4492b9afc0 C
  │ │
  @ │  15ed2d917603 H
  │ │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ sl log --hidden -G
  o  6513e8468c61 B
  │
  │ o  b9a00f7e0244 D
  │ │
  │ o  6c4492b9afc0 C
  │ │
  @ │  15ed2d917603 H
  │ │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  │ x  b3325c91a4d9 D (rewritten using rebase as b9a00f7e0244)
  │ │
  │ x  f838bfaca5c7 C (rewritten using rebase as 6c4492b9afc0)
  │ │
  │ x  27547f69f254 B (rewritten using rebase as 6513e8468c61)
  ├─╯
  o  4a2df7238c3b A
  
  $ sl debugmutation -r 8 -r 9 -r 10
   *  6c4492b9afc04f340e0e5693b3b00e15ad725280 rebase by test at 1970-01-01T00:00:00 from:
      f838bfaca5c7226600ebcfd84f3c3c13a28d3757
  
   *  b9a00f7e0244332a0e8cfe117ca48bf10062a223 rebase by test at 1970-01-01T00:00:00 from:
      b3325c91a4d916bcc4cdc83ea3fe4ece46a42f6e
  
   *  6513e8468c61d630aa6a09f5577ed1ef57b8f969 rebase by test at 1970-01-01T00:00:00 from:
      27547f69f25460a52fff66ad004e58da7ad3fb56
  

Test that rewriting leaving instability behind is allowed
---------------------------------------------------------------------

  $ sl log -r 'children(max(desc(C)))'
  b9a00f7e0244 D (no-eol)
  $ sl rebase -r 'max(desc(C))' -d 'desc(B)'
  rebasing 6c4492b9afc0 "C"
  $ sl log -G
  o  fb16c8a4d41d C
  │
  o  6513e8468c61 B
  │
  │ o  b9a00f7e0244 D
  │ │
  │ x  6c4492b9afc0 C (rewritten using rebase as fb16c8a4d41d)
  │ │
  @ │  15ed2d917603 H
  │ │
  │ o  3dbfcf9931fb G
  ╭─┤
  o │  c137c2b8081f F
  │ │
  │ o  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  


Test multiple root handling
------------------------------------

  $ sl rebase --dest 'desc(E)' --rev 'desc(H)+11+9'
  rebasing 15ed2d917603 "H"
  rebasing fb16c8a4d41d "C"
  rebasing b9a00f7e0244 "D"
  $ sl log -G
  o  519f68ee3858 D
  │
  │ o  7af31ae01a50 C
  │ │
  │ @  0ecbffe392a3 H
  ├─╯
  │ o  6513e8468c61 B
  │ │
  │ x  15ed2d917603 H (rewritten using rebase as 0ecbffe392a3)
  │ │
  │ │ o  3dbfcf9931fb G
  ╭─┬─╯
  │ o  c137c2b8081f F
  │ │
  o │  4e18486b3568 E
  ├─╯
  o  4a2df7238c3b A
  
  $ cd ..

Detach both parents

  $ sl init double-detach
  $ cd double-detach

  $ drawdag <<EOF
  >   F
  >  /|
  > C E
  > | |
  > B D G
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(G)" -r "desc(B) + desc(D) + desc(F)"
  rebasing b18e25de2cf5 "D"
  rebasing 112478962961 "B"
  rebasing f15c3adaf214 "F"
  abort: cannot rebase f15c3adaf214 without moving at least one of its parents
  [255]

  $ cd ..

test on rebase dropping a merge

(setup)

  $ cp -R base dropmerge
  $ cd dropmerge
  $ sl up 'desc(D)'
  3 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl merge 'desc(H)'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m 'M'
  $ echo I > I
  $ sl add I
  $ sl ci -m I
  $ sl log -G
  @  b1503e71269e I
  │
  o    afaad9b542d8 M
  ├─╮
  │ o  15ed2d917603 H
  │ │
  │ │ o  3dbfcf9931fb G
  │ ╭─┤
  │ o │  c137c2b8081f F
  │ │ │
  │ │ o  4e18486b3568 E
  │ ├─╯
  o │  b3325c91a4d9 D
  │ │
  o │  f838bfaca5c7 C
  │ │
  o │  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
(actual test)

  $ sl rebase --dest 'desc(G)' --rev '((desc(H) + desc(D))::) - desc(M)'
  rebasing 15ed2d917603 "H"
  rebasing b3325c91a4d9 "D"
  rebasing b1503e71269e "I"
  $ sl log -G
  @  81b9c3afc5f1 I
  │
  │ o  783cb424299f D
  │ │
  o │  c714c1931d9f H
  ├─╯
  │ o    afaad9b542d8 M
  │ ├─╮
  │ │ x  15ed2d917603 H (rewritten using rebase as c714c1931d9f)
  │ │ │
  o │ │  3dbfcf9931fb G
  ├───╮
  │ │ o  c137c2b8081f F
  │ │ │
  o │ │  4e18486b3568 E
  ├───╯
  │ x  b3325c91a4d9 D (rewritten using rebase as 783cb424299f)
  │ │
  │ o  f838bfaca5c7 C
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  

Test hidden changesets in the rebase set (issue4504)

  $ sl up --hidden 'min(desc(I))'
  3 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ echo J > J
  $ sl add J
  $ sl commit -m J
  $ sl --config extensions.amend= hide -q ".^"
  $ sl up -q --hidden "desc(J)"

  $ sl rebase --rev .~1::. --dest 'max(desc(D))' --traceback --config experimental.rebaseskipobsolete=off
  rebasing b1503e71269e "I"
  rebasing 310ee67cd06b "J"
  $ sl log -G
  @  b37111507b7f J
  │
  o  d5d779cd3731 I
  │
  │ o  81b9c3afc5f1 I
  │ │
  o │  783cb424299f D
  │ │
  │ o  c714c1931d9f H
  ├─╯
  │ o    afaad9b542d8 M
  │ ├─╮
  │ │ x  15ed2d917603 H (rewritten using rebase as c714c1931d9f)
  │ │ │
  o │ │  3dbfcf9931fb G
  ├───╮
  │ │ o  c137c2b8081f F
  │ │ │
  o │ │  4e18486b3568 E
  ├───╯
  │ x  b3325c91a4d9 D (rewritten using rebase as 783cb424299f)
  │ │
  │ o  f838bfaca5c7 C
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ sl up 'max(desc(I))' -C
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "K" > K
  $ sl add K
  $ sl commit --amend -m "K"
  $ echo "L" > L
  $ sl add L
  $ sl commit -m "L"
  $ sl up '.^'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "M" > M
  $ sl add M
  $ sl commit --amend -m "M"
  $ sl log -G
  @  5971eedbdd0c M
  │
  │ o  036ee639b269 L
  │ │
  │ x  2aa9c55690c5 K (rewritten using amend as 5971eedbdd0c)
  ├─╯
  │ o  b37111507b7f J
  │ │
  │ x  d5d779cd3731 I (rewritten using amend as 2aa9c55690c5)
  ├─╯
  │ o  81b9c3afc5f1 I
  │ │
  o │  783cb424299f D
  │ │
  │ o  c714c1931d9f H
  ├─╯
  │ o    afaad9b542d8 M
  │ ├─╮
  │ │ x  15ed2d917603 H (rewritten using rebase as c714c1931d9f)
  │ │ │
  o │ │  3dbfcf9931fb G
  ├───╮
  │ │ o  c137c2b8081f F
  │ │ │
  o │ │  4e18486b3568 E
  ├───╯
  │ x  b3325c91a4d9 D (rewritten using rebase as 783cb424299f)
  │ │
  │ o  f838bfaca5c7 C
  │ │
  │ o  27547f69f254 B
  ├─╯
  o  4a2df7238c3b A
  
  $ sl rebase -s 'max(desc(I))' -d 'desc(L)' --config experimental.rebaseskipobsolete=True
  note: not rebasing d5d779cd3731 "I", already in destination as 2aa9c55690c5 "K"
  rebasing b37111507b7f "J"

  $ cd ..

Skip obsolete changeset even with multiple hops
-----------------------------------------------

setup

  $ sl init obsskip
  $ cd obsskip
  $ cat << EOF >> .sl/config
  > [experimental]
  > rebaseskipobsolete = True
  > [extensions]
  > strip =
  > EOF
  $ echo A > A
  $ sl add A
  $ sl commit -m A
  $ echo B > B
  $ sl add B
  $ sl commit -m B0
  $ sl commit --amend -m B1
  $ sl commit --amend -m B2
  $ sl up --hidden 'desc(B0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo C > C
  $ sl add C
  $ sl commit -m C
  $ sl log -G
  @  212cb178bcbb C
  │
  │ o  261e70097290 B2
  │ │
  x │  a8b11f55fb19 B0 (rewritten using rewrite as 261e70097290)
  ├─╯
  o  4a2df7238c3b A
  

Rebase finds its way in a chain of marker

  $ sl rebase -d 'desc(B2)'
  note: not rebasing a8b11f55fb19 "B0", already in destination as 261e70097290 "B2"
  rebasing 212cb178bcbb "C"

Even when the chain include missing node

  $ sl up --hidden 'desc(B0)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo D > D
  $ sl add D
  $ sl commit -m D

  $ enable amend
  $ sl hide 212cb178bcbb8916f22a2bf937232f368b64ace7 -q --hidden

  $ sl log -G
  @  1a79b7535141 D
  │
  │ o  ff2c4d47b71d C
  │ │
  │ o  261e70097290 B2
  │ │
  x │  a8b11f55fb19 B0 (rewritten using rewrite as 261e70097290)
  ├─╯
  o  4a2df7238c3b A
  

  $ sl rebase -d 'desc(B2)'
  note: not rebasing a8b11f55fb19 "B0", already in destination as 261e70097290 "B2"
  rebasing 1a79b7535141 "D"
  $ sl up 'max(desc(C))'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "O" > O
  $ sl add O
  $ sl commit -m O
  $ echo "P" > P
  $ sl add P
  $ sl commit -m P
  $ sl log -G
  @  8d47583e023f P
  │
  o  360bbaa7d3ce O
  │
  │ o  9c48361117de D
  │ │
  o │  ff2c4d47b71d C
  ├─╯
  o  261e70097290 B2
  │
  o  4a2df7238c3b A
  
  $ sl rebase -d 'max(desc(D))' -r "ff2c4d47b71d942eb1f1914b2cb5fe3a328f1ba9+8d47583e023f"
  rebasing ff2c4d47b71d "C"
  rebasing 8d47583e023f "P"
  $ sl hide 'desc(O)' --config extensions.amend=
  hiding commit 360bbaa7d3ce "O"
  1 changeset hidden

If all the changeset to be rebased are obsolete and present in the destination, we
should display a friendly error message

  $ sl log -G
  @  121d9e3bc4c6 P
  │
  o  4be60e099a77 C
  │
  o  9c48361117de D
  │
  o  261e70097290 B2
  │
  o  4a2df7238c3b A
  

Rebases can create divergence

  $ sl log -G
  @  121d9e3bc4c6 P
  │
  o  4be60e099a77 C
  │
  o  9c48361117de D
  │
  o  261e70097290 B2
  │
  o  4a2df7238c3b A
  

  $ sl up 'max(desc(C))'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "john" > doe
  $ sl add doe
  $ sl commit -m "john doe"
  $ sl up 'max(desc(P))'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "foo" > bar
  $ sl add bar
  $ sl commit --amend -m "P-amended"
  $ sl up 121d9e3bc4c60bd1c9c007e7de31d6796b882a45 --hidden
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo "bar" > foo
  $ sl add foo
  $ sl commit -m "bar foo"
  $ sl log -G
  @  73568ab6879d bar foo
  │
  │ o  e75f87cd16c5 P-amended
  │ │
  │ │ o  3eb461388009 john doe
  │ ├─╯
  x │  121d9e3bc4c6 P (rewritten using amend as e75f87cd16c5)
  ├─╯
  o  4be60e099a77 C
  │
  o  9c48361117de D
  │
  o  261e70097290 B2
  │
  o  4a2df7238c3b A
  
  $ sl rebase -s 121d9e3bc4c60bd1c9c007e7de31d6796b882a45 -d 'desc(john)'
  rebasing 121d9e3bc4c6 "P"
  rebasing 73568ab6879d "bar foo"
  $ sl log -G
  @  61bd55f69bc4 bar foo
  │
  o  5f53594f6882 P
  │
  │ o  e75f87cd16c5 P-amended
  │ │
  o │  3eb461388009 john doe
  ├─╯
  o  4be60e099a77 C
  │
  o  9c48361117de D
  │
  o  261e70097290 B2
  │
  o  4a2df7238c3b A
  
rebase --continue + skipped rev because their successors are in destination
we make a change in trunk and work on conflicting changes to make rebase abort.

  $ sl log -G -r 'max(desc(bar))'::
  @  61bd55f69bc4 bar foo
  │
  ~

Create a change in trunk
  $ printf "a" > willconflict
  $ sl add willconflict
  $ sl commit -m "willconflict first version"

Create the changes that we will rebase
  $ sl goto -C 'max(desc(bar))' -q
  $ printf "b" > willconflict
  $ sl add willconflict
  $ sl commit -m "willconflict second version"
  $ printf "dummy" > K
  $ sl add K
  $ sl commit -m "dummy change 1"
  $ printf "dummy" > L
  $ sl add L
  $ sl commit -m "dummy change 2"
  $ sl rebase -r cab092d71c4b6b4c735990a4c35f9bf949c73b12 -d 357ddf1602d5a49a02a6d216eeb0d5cc37a1f036
  rebasing cab092d71c4b "dummy change 1"

  $ sl log -G -r 'max(desc(bar))'::
  o  59c6f3a91215 dummy change 1
  │
  │ @  ae4ed1351416 dummy change 2
  │ │
  │ x  cab092d71c4b dummy change 1 (rewritten using rebase as 59c6f3a91215)
  │ │
  │ o  b82fb57ea638 willconflict second version
  │ │
  o │  357ddf1602d5 willconflict first version
  ├─╯
  o  61bd55f69bc4 bar foo
  │
  ~
  $ sl rebase -r ".^^ + .^ + ." -d 'max(desc(dummy))'
  rebasing b82fb57ea638 "willconflict second version"
  merging willconflict
  warning: 1 conflicts while merging willconflict! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

  $ sl resolve --mark willconflict
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  rebasing b82fb57ea638 "willconflict second version"
  note: not rebasing cab092d71c4b "dummy change 1", already in destination as 59c6f3a91215 "dummy change 1"
  rebasing ae4ed1351416 "dummy change 2"
  $ cd ..

Divergence cases due to obsolete changesets
-------------------------------------------

We should ignore branches with unstable changesets when they are based on an
obsolete changeset which successor is in rebase set.

  $ sl init divergence
  $ cd divergence
  $ cat >> .sl/config << EOF
  > [templates]
  > instabilities = '{node|short} {desc|firstline}{if(instabilities," ({instabilities})")}\n'
  > EOF

  $ drawdag <<EOF
  >   e   f
  >   |   |
  >   d2  d # replace: d -> d2
  >    \ /
  >     c
  >     |
  >   x b
  >    \|
  >     a
  > EOF
  $ sl log -G -r $a::
  o  493e1ea05b71 e
  │
  │ o  1143e9adc121 f
  │ │
  o │  447acf26a46a d2
  │ │
  │ x  76be324c128b d (rewritten using replace as 447acf26a46a)
  ├─╯
  o  a82ac2b38757 c
  │
  │ o  630d7c95eff7 x
  │ │
  o │  488e1b7e7341 b
  ├─╯
  o  b173517d0057 a
  

Changeset d and its descendants are excluded to avoid divergence of d, which
would occur because the successor of d (d2) is also in rebaseset. As a
consequence f (descendant of d) is left behind.

  $ sl rebase -b $e -d $x
  rebasing 488e1b7e7341 "b"
  rebasing a82ac2b38757 "c"
  note: not rebasing 76be324c128b "d" and its descendants as this would cause divergence
  rebasing 447acf26a46a "d2"
  rebasing 493e1ea05b71 "e"
  $ sl log -G -r $a::
  o  1ce56955f155 e
  │
  o  885d062b1232 d2
  │
  o  d008e6b4d3fd c
  │
  o  67e8f4a16c49 b
  │
  │ o  1143e9adc121 f
  │ │
  │ x  76be324c128b d (rewritten using rewrite as 885d062b1232)
  │ │
  │ x  a82ac2b38757 c (rewritten using rebase as d008e6b4d3fd)
  │ │
  o │  630d7c95eff7 x
  │ │
  │ x  488e1b7e7341 b (rewritten using rebase as 67e8f4a16c49)
  ├─╯
  o  b173517d0057 a
  

  $ sl debugmutation -r "desc(d2) & $a::"
   *  885d062b12325adcee99e6cffe64beab3e3fa72d rebase by test at 1970-01-01T00:00:00 from:
      447acf26a46a3399a7d18e2bd63f0762b7198405 replace by test at 1970-01-01T00:00:00 from:
      76be324c128b88631d4bff1b65a6cfe23096d1f6
  
  $ sl debugstrip --no-backup -q -r 'max(desc(b))':

If the rebase set has an obsolete (d) with a successor (d2) outside the rebase
set and none in destination, then divergence is allowed.

  $ sl unhide -r $d2+$e --config extensions.amend=
  $ sl rebase -r $c::$f -d $x
  rebasing a82ac2b38757 "c"
  rebasing 76be324c128b "d"
  rebasing 1143e9adc121 "f"
  $ sl log -G -r $a::
  o  e1744ea07510 f
  │
  o  e2b36ea9a0a0 d
  │
  o  6a0376de376e c
  │
  │ o  493e1ea05b71 e
  │ │
  │ o  447acf26a46a d2
  │ │
  │ x  a82ac2b38757 c (rewritten using rebase as 6a0376de376e)
  │ │
  o │  630d7c95eff7 x
  │ │
  │ o  488e1b7e7341 b
  ├─╯
  o  b173517d0057 a
  
  $ sl debugstrip --no-backup -q -r 'max(desc(c))':

(Not skipping obsoletes means that divergence is allowed.)

  $ sl unhide -r $f --config extensions.amend=
  $ sl rebase --config experimental.rebaseskipobsolete=false -r $c::$f -d $x
  rebasing a82ac2b38757 "c"
  rebasing 76be324c128b "d"
  rebasing 1143e9adc121 "f"

  $ sl debugstrip --no-backup -q -r 'desc(a)':

Similar test on a more complex graph

  $ drawdag <<EOF
  >       g
  >       |
  >   f   e
  >   |   |
  >   e2  d # replace: e -> e2
  >    \ /
  >     c
  >     |
  >   x b
  >    \|
  >     a
  > EOF
  $ sl log -G -r $a:
  o  12df856f4e8e f
  │
  │ o  2876ce66c6eb g
  │ │
  o │  87682c149ad7 e2
  │ │
  │ x  e36fae928aec e (rewritten using replace as 87682c149ad7)
  │ │
  │ o  76be324c128b d
  ├─╯
  o  a82ac2b38757 c
  │
  │ o  630d7c95eff7 x
  │ │
  o │  488e1b7e7341 b
  ├─╯
  o  b173517d0057 a
  
  $ sl rebase -b $f -d $x
  rebasing 488e1b7e7341 "b"
  rebasing a82ac2b38757 "c"
  rebasing 76be324c128b "d"
  note: not rebasing e36fae928aec "e" and its descendants as this would cause divergence
  rebasing 87682c149ad7 "e2"
  rebasing 12df856f4e8e "f"

FIXME: 121d9e3bc4c6 and 87682c149ad7 should be hidden.
  $ sl log -G -r "$a::(not obsolete())"
  o  aa3f1f628d29 f
  │
  o  2963fc7a5743 e2
  │
  │ o  a1707a5b7c2c d
  ├─╯
  o  d008e6b4d3fd c
  │
  o  67e8f4a16c49 b
  │
  │ o  12df856f4e8e f
  │ │
  │ │ o  2876ce66c6eb g
  │ │ │
  │ o │  87682c149ad7 e2
  │ │ │
  │ │ x  e36fae928aec e (rewritten using rewrite as 2963fc7a5743)
  │ │ │
  │ │ x  76be324c128b d (rewritten using rebase as a1707a5b7c2c)
  │ ├─╯
  │ x  a82ac2b38757 c (rewritten using rebase as d008e6b4d3fd)
  │ │
  o │  630d7c95eff7 x
  │ │
  │ x  488e1b7e7341 b (rewritten using rebase as 67e8f4a16c49)
  ├─╯
  o  b173517d0057 a
  

  $ cd ..

Rebase merge where successor of one parent is equal to destination (issue5198)

  $ sl init p1-succ-is-dest
  $ cd p1-succ-is-dest

  $ drawdag <<EOF
  >   F
  >  /|
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d $B -s "desc(D)"
  note: not rebasing b18e25de2cf5 "D", already in destination as 112478962961 "B"
  rebasing 66f1a38021c9 "F"
  $ sl log -G
  o    50e9d60b99c6 F
  ├─╮
  │ o  112478962961 B
  │ │
  o │  7fb047a69f22 E
  ├─╯
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is equal to destination

  $ sl init p2-succ-is-dest
  $ cd p2-succ-is-dest

  $ drawdag <<EOF
  >   F
  >  /|
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(B)" -s "desc(E)"
  note: not rebasing 7fb047a69f22 "E", already in destination as 112478962961 "B"
  rebasing 66f1a38021c9 "F"
  $ sl log -G
  o    aae1787dacee F
  ├─╮
  │ o  112478962961 B
  │ │
  o │  b18e25de2cf5 D
  ├─╯
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where successor of one parent is ancestor of destination

  $ sl init p1-succ-in-dest
  $ cd p1-succ-in-dest

  $ drawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(C)" -s "desc(D)"
  note: not rebasing b18e25de2cf5 "D", already in destination as 112478962961 "B"
  rebasing 66f1a38021c9 "F"

  $ sl log -G
  o    0913febf6439 F
  ├─╮
  │ o  26805aba1e60 C
  │ │
  │ o  112478962961 B
  │ │
  o │  7fb047a69f22 E
  ├─╯
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is ancestor of destination

  $ sl init p2-succ-in-dest
  $ cd p2-succ-in-dest

  $ drawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(C)" -s "desc(E)"
  note: not rebasing 7fb047a69f22 "E", already in destination as 112478962961 "B"
  rebasing 66f1a38021c9 "F"
  $ sl log -G
  o    c6ab0cc6d220 F
  ├─╮
  │ o  26805aba1e60 C
  │ │
  │ o  112478962961 B
  │ │
  o │  b18e25de2cf5 D
  ├─╯
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where successor of one parent is ancestor of destination

  $ sl init p1-succ-in-dest-b
  $ cd p1-succ-in-dest-b

  $ drawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: E -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(C)" -b "desc(F)"
  note: not rebasing 7fb047a69f22 "E", already in destination as 112478962961 "B"
  rebasing b18e25de2cf5 "D"
  rebasing 66f1a38021c9 "F"
  note: not rebasing 66f1a38021c9, its destination (rebasing onto) commit already has all its changes
  $ sl log -G
  o  8f47515dda15 D
  │
  o  26805aba1e60 C
  │
  o  112478962961 B
  │
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where successor of other parent is ancestor of destination

  $ sl init p2-succ-in-dest-b
  $ cd p2-succ-in-dest-b

  $ drawdag <<EOF
  >   F C
  >  /| |
  > E D B # replace: D -> B
  >  \|/
  >   A
  > EOF

  $ sl rebase -d "desc(C)" -b "desc(F)"
  rebasing 7fb047a69f22 "E"
  note: not rebasing b18e25de2cf5 "D", already in destination as 112478962961 "B"
  rebasing 66f1a38021c9 "F"
  note: not rebasing 66f1a38021c9, its destination (rebasing onto) commit already has all its changes

  $ sl log -G
  o  533690786a86 E
  │
  o  26805aba1e60 C
  │
  o  112478962961 B
  │
  o  426bada5c675 A
  
  $ cd ..

Rebase merge where both parents have successors in destination

  $ sl init p12-succ-in-dest
  $ cd p12-succ-in-dest
  $ drawdag <<'EOS'
  >   E   F
  >  /|  /|  # replace: A -> C
  > A B C D  # replace: B -> D
  > | |
  > X Y
  > EOS
  $ sl rebase -r "desc(A)+desc(B)+desc(E)" -d "desc(F)"
  note: not rebasing a3d17304151f "A", already in destination as 96cc3511f894 "C"
  note: not rebasing b23a2cc00842 "B", already in destination as 058c1e1fb10a "D"
  rebasing dac5d11c5a7d "E"
  abort: rebasing dac5d11c5a7d will include unwanted changes from 59c792af609c, b23a2cc00842 or ba2b7fa7166d, a3d17304151f
  [255]
  $ cd ..

Rebase a non-clean merge. One parent has successor in destination, the other
parent moves as requested.

  $ sl init p1-succ-p2-move
  $ cd p1-succ-p2-move
  $ drawdag <<'EOS'
  >   D Z
  >  /| | # replace: A -> C
  > A B C # D/D = D
  > EOS
  $ sl rebase -r "desc(A)+desc(B)+desc(D)" -d "desc(Z)"
  note: not rebasing 426bada5c675 "A", already in destination as 96cc3511f894 "C"
  rebasing fc2b737bb2e5 "B"
  rebasing b8ed089c80ad "D"

  $ sl log -G
  o  e4f78693cc88 D
  │
  o  76840d832e98 B
  │
  o  50e41c1f3950 Z
  │
  o  96cc3511f894 C
  
  $ sl files -r tip
  B
  C
  D
  Z

  $ cd ..

  $ sl init p1-move-p2-succ
  $ cd p1-move-p2-succ
  $ drawdag <<'EOS'
  >   D Z
  >  /| |  # replace: B -> C
  > A B C  # D/D = D
  > EOS
  $ sl rebase -r "desc(B)+desc(A)+desc(D)" -d "desc(Z)"
  rebasing 426bada5c675 "A"
  note: not rebasing fc2b737bb2e5 "B", already in destination as 96cc3511f894 "C"
  rebasing b8ed089c80ad "D"

  $ sl log -G
  o  1b355ed94d82 D
  │
  o  a81a74d764a6 A
  │
  o  50e41c1f3950 Z
  │
  o  96cc3511f894 C
  
  $ sl files -r tip
  A
  C
  D
  Z

  $ cd ..

Test that bookmark is moved and working dir is updated when all changesets have
equivalents in destination
  $ sl init rbsrepo && cd rbsrepo
  $ echo "[experimental]" > .sl/config
  $ echo "evolution=true" >> .sl/config
  $ echo "rebaseskipobsolete=on" >> .sl/config
  $ echo root > root && sl ci -Am root
  adding root
  $ echo a > a && sl ci -Am a
  adding a
  $ sl up 'desc(root)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo b > b && sl ci -Am b
  adding b
  $ sl rebase -r 'desc(b)' -d 'desc(a)'
  rebasing 1e9a3c00cbe9 "b"
  $ sl log -r .  # working dir is at rev 3 (successor of 2)
  be1832deae9a b (no-eol)
  $ sl book -r 1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc mybook --hidden  # rev 1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc has a bookmark on it now
  $ sl up 1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc && sl log -r .  # working dir is at rev 1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc again
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  1e9a3c00cbe9 b (rewritten using rebase as be1832deae9a) (no-eol)
  $ sl rebase -r 1e9a3c00cbe90d236ac05ef61efcc5e40b7412bc -d 'max(desc(b))'
  note: not rebasing 1e9a3c00cbe9 "b" (mybook), already in destination as be1832deae9a "b"
Check that working directory and bookmark was updated to rev 3 although rev 2
was skipped
  $ sl log -r .
  be1832deae9a b (no-eol)
  $ sl bookmarks
     mybook                    be1832deae9a
  $ sl debugobsolete --rev tip

Obsoleted working parent and bookmark could be moved if an ancestor of working
parent gets moved:

  $ sl init $TESTTMP/ancestor-wd-move
  $ cd $TESTTMP/ancestor-wd-move
  $ drawdag <<'EOS'
  >  E D1  # rebase: D1 -> D2
  >  | |
  >  | C
  > D2 |
  >  | B
  >  |/
  >  A
  > EOS
  $ sl goto "desc(D1)" -q --hidden
  $ sl bookmark book -i
  $ sl rebase -r "desc(B)+desc(D1)" -d "desc(E)"
  rebasing 112478962961 "B"
  note: not rebasing 15ecf15e0114 "D1" (book), already in destination as 0807738e0be9 "D2"
  $ sl log -G -T '{desc} {bookmarks}'
  @  B book
  │
  o  E
  │
  o  D2
  │
  │ o  C
  │ │
  │ x  B
  ├─╯
  o  A
  
Rebasing a merge with one of its parent having a hidden successor

  $ sl init $TESTTMP/merge-p1-hidden-successor
  $ cd $TESTTMP/merge-p1-hidden-successor

  $ drawdag <<'EOS'
  >  E
  >  |
  > B3 B2 # amend: B1 -> B2 -> B3
  >  |/   # B2 is hidden
  >  |  D
  >  |  |\
  >  | B1 C
  >  |/
  >  A
  > EOS

  $ sl rebase -r $D -d $E
  rebasing 9e62094e4d94 "D"

  $ sl log -G
  o    a699d059adcf D
  ├─╮
  │ o  ecc93090a95c E
  │ │
  │ o  0dc878468a23 B3
  │ │
  o │  96cc3511f894 C
    │
    o  426bada5c675 A
  
For some reasons (--hidden, rebaseskipobsolete=0, directaccess, etc.),
rebasestate may contain hidden hashes. "rebase --abort" should work regardless.

  $ sl init $TESTTMP/hidden-state1
  $ cd $TESTTMP/hidden-state1
  $ setconfig experimental.rebaseskipobsolete=0

  $ drawdag <<'EOS'
  >    C
  >    |
  >  D B
  >  |/  # B/D=B
  >  A
  > EOS

  $ sl hide -q $B --config extensions.amend=
  $ sl goto -q $C --hidden
  $ sl rebase -s $B -d $D
  rebasing 2ec65233581b "B"
  merging D
  warning: 1 conflicts while merging D! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]

  $ cp -R . $TESTTMP/hidden-state2

  $ sl log -G
  @  b18e25de2cf5 D
  │
  │ @  2ec65233581b B
  ├─╯
  o  426bada5c675 A
  
  $ sl summary
  parent: b18e25de2cf5 
   D
  parent: 2ec65233581b 
   B
  commit: 2 modified, 1 unknown, 1 unresolved (merge)
  phases: 3 draft
  rebase: 0 rebased, 2 remaining (rebase --continue)

  $ sl rebase --abort
  rebase aborted

Also test --continue for the above case

  $ cd $TESTTMP/hidden-state2
  $ sl resolve -m
  (no more unresolved files)
  continue: sl rebase --continue
  $ sl rebase --continue
  rebasing 2ec65233581b "B"
  rebasing 7829726be4dc "C"
  $ sl log -G
  @  1964d5d5b547 C
  │
  o  68deb90c12a2 B
  │
  o  b18e25de2cf5 D
  │
  o  426bada5c675 A
  
