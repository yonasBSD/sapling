
#require serve no-eden

  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true

#if no-outer-repo
no repo

  $ sl id
  abort: there is no Mercurial repository here (.sl not found)
  [255]

#endif

  $ configure dummyssh

create repo

  $ sl init test
  $ cd test
  $ echo a > a
  $ sl ci -Ama
  adding a

basic id usage

  $ sl id
  cb9a9f314b8b
  $ sl id --debug
  cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b
  $ sl id -q
  cb9a9f314b8b
  $ sl id -v
  cb9a9f314b8b

with options

  $ sl id -r.
  cb9a9f314b8b
  $ sl id -n
  0
  $ sl id -b
  default
  $ sl id -i
  cb9a9f314b8b
  $ sl id -n -t -b -i
  cb9a9f314b8b 0 default
  $ sl id -Tjson
  [
   {
    "bookmarks": [],
    "dirty": "",
    "id": "cb9a9f314b8b",
    "node": "ffffffffffffffffffffffffffffffffffffffff",
    "parents": [{"node": "cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b", "rev": 0}]
   }
  ]

test template keywords and functions which require changectx:
(The Rust layer does not special handle the wdir commit hash so shortest does
not "work" here.  In the future we want to change virtual commits handling to
use normal (non-special-cased) in-memory-only commits in the Rust DAG instead
of special casing them in various APIs (ex. partialmatch))

  $ sl id -T '{node|shortest}\n'
  ffffffffffffffffffffffffffffffffffffffff
  $ sl id -T '{parents % "{node|shortest} {desc}\n"}'
  cb9a a

with modifications

  $ echo b > a
  $ sl id -n -t -b -i
  cb9a9f314b8b+ 0+ default
  $ sl id -Tjson
  [
   {
    "bookmarks": [],
    "dirty": "+",
    "id": "cb9a9f314b8b+",
    "node": "ffffffffffffffffffffffffffffffffffffffff",
    "parents": [{"node": "cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b", "rev": 0}]
   }
  ]

other local repo

  $ cd ..
  $ sl -R test id
  cb9a9f314b8b+
#if no-outer-repo
  $ sl id test
  cb9a9f314b8b+ tip
#endif

with remote ssh repo

  $ cd test
  $ sl id ssh://user@dummy/test
  cb9a9f314b8b

remote with rev number?

  $ sl id -n ssh://user@dummy/test
  abort: can't query remote revision number or branch
  [255]

remote with branch?

  $ sl id -b ssh://user@dummy/test
  abort: can't query remote revision number or branch
  [255]

test bookmark support

  $ sl bookmark Y
  $ sl bookmark Z
  $ sl bookmarks
     Y                         cb9a9f314b8b
   * Z                         cb9a9f314b8b
  $ sl id
  cb9a9f314b8b+ Y/Z
  $ sl id --bookmarks
  Y Z

test remote identify with bookmarks

  $ sl id ssh://user@dummy/test
  cb9a9f314b8b Y/Z
  $ sl id --bookmarks ssh://user@dummy/test
  Y Z
  $ sl id -r . ssh://user@dummy/test
  cb9a9f314b8b Y/Z
  $ sl id --bookmarks -r . ssh://user@dummy/test
  Y Z

test invalid lookup

  $ sl id -r noNoNO ssh://user@dummy/test
  abort: unknown revision 'noNoNO'!
  [255]

Make sure we do not obscure unknown requires file entries (issue2649)

  $ echo fake >> .sl/requires
  $ sl id
  abort: repository requires unknown features: fake
  (consider upgrading Sapling)
  [255]

  $ cd ..
#if no-outer-repo
  $ sl id test
  abort: repository requires features unknown to this Mercurial: fake!
  (see https://mercurial-scm.org/wiki/MissingRequirement for more information)
  [255]
#endif
