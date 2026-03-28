#require no-windows no-eden
  $ export HGIDENTITY=sl
  $ enable smartlog
  $ disable commitcloud
  $ newclientrepo
  $ sl debugdrawdag <<'EOS'
  > c d
  > |/
  > b
  > |
  > a
  > EOS
  $ export SL_CONFIG_PATH="$SL_CONFIG_PATH;fb=static"
  $ cat > transcript <<EOF
  > j
  > j
  > q
  > EOF

  $ sl sl -i < transcript
  ===== Screen Refresh =====
  o  f4016ed9f  Today at 00:00  test  d
  │  d
  │
  │ o  a82ac2b38  Today at 00:00  test  c
  ├─╯  c
  │
  o  488e1b7e7  Today at 00:00  test  b
  │  b
  │
  o  b173517d0  Today at 00:00  test  a
     a
  ===== Screen Refresh =====
  o  f4016ed9f  Today at 00:00  test  d
  │  d
  │
  │ o  a82ac2b38  Today at 00:00  test  c
  ├─╯  c
  │
  o  488e1b7e7  Today at 00:00  test  b
  │  b
  │
  o  b173517d0  Today at 00:00  test  a
     a
  ===== Screen Refresh =====
  o  f4016ed9f  Today at 00:00  test  d
  │  d
  │
  │ o  a82ac2b38  Today at 00:00  test  c
  ├─╯  c
  │
  o  488e1b7e7  Today at 00:00  test  b
  │  b
  │
  o  b173517d0  Today at 00:00  test  a
     a
