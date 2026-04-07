#require git no-eden
#modern-config-incompatible

  $ . $TESTDIR/git.sh

Server repo

  $ sl init --git server-repo
  $ cd server-repo
  $ drawdag << 'EOS'
  > C D
  > |/
  > B
  > |
  > A
  > EOS
  $ sl bookmark -r $B main

Client repo

  $ cd
  $ sl clone -q --git "$TESTTMP/server-repo/.sl/store/git" client-repo
  $ cd client-repo
  $ sl log -Gr: -T '{desc} {remotenames} {phase}'
  @  B remote/main public
  │
  o  A  public
  
Auto pull by node

  $ sl log -r $C -T '{desc}\n'
  pulling '06625e541e5375ee630d4bc10780e8d8fbfa38f9' from * (glob)
  C

Pull by node

  $ sl pull -qr $D

  $ sl log -Gr: -T '{desc} {remotenames} {phase}'
  o  D  draft
  │
  │ o  C  draft
  ├─╯
  @  B remote/main public
  │
  o  A  public
  
