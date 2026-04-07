setup
  $ enable rebase morestatus smartlog
  $ setconfig morestatus.show=True
  $ newclientrepo
  $ drawdag <<'EOS'
  > E   # E/x = 1'\n2\n3'\n4\n5'\n
  > |
  > D   # D/x = 1'\n2\n3'\n4\n5\n
  > |
  > C   # C/x = 1'\n2\n3\n4\n5\n
  > |
  > | B # B/x = 1\n2\n3''\n4\n5\n
  > |/
  > A   # A/x = 1\n2\n3\n4\n5\n
  > EOS

  $ sl rebase -s $C -d $B
  rebasing 46825fa938fd "C"
  merging x
  rebasing af52e0612645 "D"
  merging x
  warning: 1 conflicts while merging x! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl st
  M D
  M x
  ? x.orig
  
  # The repository is in an unfinished *rebase* state.
  # Unresolved merge conflicts (1):
  # 
  #     x
  # 
  # To mark files as resolved:  sl resolve --mark FILE
  # To continue:                sl rebase --continue
  # To abort:                   sl rebase --abort
  # To quit:                    sl rebase --quit
  # 
  # Rebasing af52e0612645 (D)
  #       to ef1eede16aff (C)

'rebase --quit' quits from the rebase state and keep the already rebased commits
  $ sl rebase --quit
  rebase quited
  $ sl log -G -T '{node|short} {desc}\n'
  @  ef1eede16aff C
  │
  │ o  2b871263512c E
  │ │
  │ o  af52e0612645 D
  │ │
  │ x  46825fa938fd C
  │ │
  o │  7219c21097ef B
  ├─╯
  o  43f996478d8a A

test --quit when --keep is passed
  $ newclientrepo
  $ drawdag <<'EOS'
  > E   # E/x = 1'\n2\n3'\n4\n5'\n
  > |
  > D   # D/x = 1'\n2\n3'\n4\n5\n
  > |
  > C   # C/x = 1'\n2\n3\n4\n5\n
  > |
  > | B # B/x = 1\n2\n3''\n4\n5\n
  > |/
  > A   # A/x = 1\n2\n3\n4\n5\n
  > EOS
  $ sl rebase -s $C -d $B --keep
  rebasing 46825fa938fd "C"
  merging x
  rebasing af52e0612645 "D"
  merging x
  warning: 1 conflicts while merging x! (edit, then use 'sl resolve --mark')
  unresolved conflicts (see sl resolve, then sl rebase --continue)
  [1]
  $ sl rebase --quit
  rebase quited
  $ sl log -G -T '{node|short} {desc}\n'
  @  ef1eede16aff C
  │
  │ o  2b871263512c E
  │ │
  │ o  af52e0612645 D
  │ │
  │ o  46825fa938fd C
  │ │
  o │  7219c21097ef B
  ├─╯
  o  43f996478d8a A
