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
  > k
  > j
  > q
  > EOF

  $ sl sl -i --config ui.color=debug < transcript
  ===== Screen Refresh =====
  o  [sl.highlighted|[sl.draft|f4016ed9f]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|d]
  │  [sl.desc|d]
  │  ]
  │ o  [sl.draft|a82ac2b38]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|c]
  ├─╯  [sl.desc|c]
  │
  o  [sl.draft|488e1b7e7]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|b]
  │  [sl.desc|b]
  │
  o  [sl.draft|b173517d0]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|a]
     [sl.desc|a]
  ===== Screen Refresh =====
  o  [sl.draft|f4016ed9f]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|d]
  │  [sl.desc|d]
  │
  │ o  [sl.highlighted|[sl.draft|a82ac2b38]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|c]
  ├─╯  [sl.desc|c]
  │    ]
  o  [sl.draft|488e1b7e7]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|b]
  │  [sl.desc|b]
  │
  o  [sl.draft|b173517d0]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|a]
     [sl.desc|a]
  ===== Screen Refresh =====
  o  [sl.draft|f4016ed9f]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|d]
  │  [sl.desc|d]
  │
  │ o  [sl.draft|a82ac2b38]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|c]
  ├─╯  [sl.desc|c]
  │
  o  [sl.highlighted|[sl.draft|488e1b7e7]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|b]
  │  [sl.desc|b]
  │  ]
  o  [sl.draft|b173517d0]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|a]
     [sl.desc|a]
  ===== Screen Refresh =====
  o  [sl.draft|f4016ed9f]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|d]
  │  [sl.desc|d]
  │
  │ o  [sl.highlighted|[sl.draft|a82ac2b38]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|c]
  ├─╯  [sl.desc|c]
  │    ]
  o  [sl.draft|488e1b7e7]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|b]
  │  [sl.desc|b]
  │
  o  [sl.draft|b173517d0]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|a]
     [sl.desc|a]
  ===== Screen Refresh =====
  o  [sl.draft|f4016ed9f]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|d]
  │  [sl.desc|d]
  │
  │ o  [sl.draft|a82ac2b38]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|c]
  ├─╯  [sl.desc|c]
  │
  o  [sl.highlighted|[sl.draft|488e1b7e7]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|b]
  │  [sl.desc|b]
  │  ]
  o  [sl.draft|b173517d0]  [sl.date|Today at 00:00]  [sl.user|test]  [sl.book|a]
     [sl.desc|a]
