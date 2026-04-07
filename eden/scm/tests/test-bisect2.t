#require no-eden

# The tests in test-bisect are done on a linear history. Here the
# following repository history is used for testing:
#
#                      17
#                       |
#                18    16
#                  \  /
#                   15
#                  /  \
#                 /    \
#               10     13
#               / \     |
#              /   \    |  14
#         7   6     9  12 /
#          \ / \    |   |/
#           4   \   |  11
#            \   \  |  /
#             3   5 | /
#              \ /  |/
#               2   8
#                \ /
#                 1
#                 |
#                 0

init

  $ sl init repo
  $ cd repo

committing changes

  $ echo > a
  $ echo '0' >> a
  $ sl add a
  $ sl ci -m "0" -d "0 0"
  $ echo '1' >> a
  $ sl ci -m "1" -d "1 0"
  $ echo '2' >> a
  $ sl ci -m "2" -d "2 0"
  $ echo '3' >> a
  $ sl ci -m "3" -d "3 0"
  $ echo '4' >> a
  $ sl ci -m "4" -d "4 0"

create branch

  $ sl up -r 'desc(2)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo '5' >> b
  $ sl add b
  $ sl ci -m "5" -d "5 0"

merge

  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m "merge 4,5" -d "6 0"

create branch

  $ sl up -r 5c668c22234f28603c6fabce397f632adfbd3d21
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo '7' > c
  $ sl add c
  $ sl ci -m "7" -d "7 0"

create branch

  $ sl up -r 'desc(1)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo '8' > d
  $ sl add d
  $ sl ci -m "8" -d "8 0"
  $ echo '9' >> d
  $ sl ci -m "9" -d "9 0"

merge

  $ sl merge -r 'desc(merge)'
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m "merge 6,9" -d "10 0"

create branch

  $ sl up -r 'desc(8)'
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo '11' > e
  $ sl add e
  $ sl ci -m "11" -d "11 0"
  $ echo '12' >> e
  $ sl ci -m "12" -d "12 0"
  $ echo '13' >> e
  $ sl ci -m "13" -d "13 0"

create branch

  $ sl up -r 'desc(11)'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo '14' > f
  $ sl add f
  $ sl ci -m "14" -d "14 0"

merge

  $ sl up -r 'desc(13)' -C
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl merge -r 'max(desc(merge))'
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl ci -m "merge 10,13" -d "15 0"
  $ echo '16' >> e
  $ sl ci -m "16" -d "16 0"
  $ echo '17' >> e
  $ sl ci -m "17" -d "17 0"

create branch

  $ sl up -r 'max(desc(merge))'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo '18' >> e
  $ sl ci -m "18" -d "18 0"

log

  $ sl log
  commit:      d42e18c7bc9b
  user:        test
  date:        Thu Jan 01 00:00:18 1970 +0000
  summary:     18
  
  commit:      228c06deef46
  user:        test
  date:        Thu Jan 01 00:00:17 1970 +0000
  summary:     17
  
  commit:      609d82a7ebae
  user:        test
  date:        Thu Jan 01 00:00:16 1970 +0000
  summary:     16
  
  commit:      857b178a7cf3
  user:        test
  date:        Thu Jan 01 00:00:15 1970 +0000
  summary:     merge 10,13
  
  commit:      faa450606157
  user:        test
  date:        Thu Jan 01 00:00:14 1970 +0000
  summary:     14
  
  commit:      b0a32c86eb31
  user:        test
  date:        Thu Jan 01 00:00:13 1970 +0000
  summary:     13
  
  commit:      9f259202bbe7
  user:        test
  date:        Thu Jan 01 00:00:12 1970 +0000
  summary:     12
  
  commit:      82ca6f06eccd
  user:        test
  date:        Thu Jan 01 00:00:11 1970 +0000
  summary:     11
  
  commit:      429fcd26f52d
  user:        test
  date:        Thu Jan 01 00:00:10 1970 +0000
  summary:     merge 6,9
  
  commit:      3c77083deb4a
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     9
  
  commit:      dab8161ac8fc
  user:        test
  date:        Thu Jan 01 00:00:08 1970 +0000
  summary:     8
  
  commit:      50c76098bbf2
  user:        test
  date:        Thu Jan 01 00:00:07 1970 +0000
  summary:     7
  
  commit:      a214d5d3811a
  user:        test
  date:        Thu Jan 01 00:00:06 1970 +0000
  summary:     merge 4,5
  
  commit:      385a529b6670
  user:        test
  date:        Thu Jan 01 00:00:05 1970 +0000
  summary:     5
  
  commit:      5c668c22234f
  user:        test
  date:        Thu Jan 01 00:00:04 1970 +0000
  summary:     4
  
  commit:      0950834f0a9c
  user:        test
  date:        Thu Jan 01 00:00:03 1970 +0000
  summary:     3
  
  commit:      051e12f87bf1
  user:        test
  date:        Thu Jan 01 00:00:02 1970 +0000
  summary:     2
  
  commit:      4ca5088da217
  user:        test
  date:        Thu Jan 01 00:00:01 1970 +0000
  summary:     1
  
  commit:      33b1f9bc8bc5
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     0
  

sl up -C

  $ sl up -C tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

complex bisect test 1  # first bad rev is 9

  $ sl bisect -r
  $ sl bisect -g 33b1f9bc8bc58c05855524ce9c1a69d916ac05f2
  $ sl bisect -b 'desc(17)'   # -> update to rev 6
  Testing changeset a214d5d3811a (15 changesets remaining, ~3 tests)
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  228c06deef46
  $ sl log -q -r 'bisect(untested)'
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  $ sl log -q -r 'bisect(ignored)'
  $ sl bisect -g      # -> update to rev 13
  Testing changeset b0a32c86eb31 (9 changesets remaining, ~3 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -s      # -> update to rev 10
  Testing changeset 429fcd26f52d (9 changesets remaining, ~3 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -b      # -> update to rev 8
  Testing changeset dab8161ac8fc (3 changesets remaining, ~1 tests)
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -g      # -> update to rev 9
  Testing changeset 3c77083deb4a (2 changesets remaining, ~1 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bisect -b
  The first bad revision is:
  commit:      3c77083deb4a
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     9
  
  $ sl log -q -r 'bisect(range)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b
  $ sl log -q -r 'bisect(untested)'
  82ca6f06eccd
  9f259202bbe7
  $ sl log -q -r 'bisect(goods)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  $ sl log -q -r 'bisect(bads)'
  3c77083deb4a
  429fcd26f52d
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b

complex bisect test 2  # first good rev is 13

  $ sl bisect -r
  $ sl bisect -g 'desc(18)'
  $ sl bisect -b 4ca5088da21701957c69801038a68cbf7b5e8dad    # -> update to rev 6
  Testing changeset a214d5d3811a (13 changesets remaining, ~3 tests)
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -s      # -> update to rev 10
  Testing changeset 429fcd26f52d (13 changesets remaining, ~3 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  a214d5d3811a
  d42e18c7bc9b
  $ sl bisect -b      # -> update to rev 12
  Testing changeset 9f259202bbe7 (5 changesets remaining, ~2 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  d42e18c7bc9b
  $ sl log -q -r 'bisect(untested)'
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  $ sl bisect -b      # -> update to rev 13
  Testing changeset b0a32c86eb31 (3 changesets remaining, ~1 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bisect -g
  The first good revision is:
  commit:      b0a32c86eb31
  user:        test
  date:        Thu Jan 01 00:00:13 1970 +0000
  summary:     13
  
  $ sl log -q -r 'bisect(range)'
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  d42e18c7bc9b

complex bisect test 3

first bad rev is 15
10,9,13 are skipped an might be the first bad revisions as well

  $ sl bisect -r
  $ sl bisect -g 4ca5088da21701957c69801038a68cbf7b5e8dad
  $ sl bisect -b 'desc(16)'   # -> update to rev 6
  Testing changeset a214d5d3811a (13 changesets remaining, ~3 tests)
  2 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  609d82a7ebae
  228c06deef46
  $ sl bisect -g      # -> update to rev 13
  Testing changeset b0a32c86eb31 (8 changesets remaining, ~3 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -s      # -> update to rev 10
  Testing changeset 429fcd26f52d (8 changesets remaining, ~3 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -s      # -> update to rev 12
  Testing changeset 9f259202bbe7 (8 changesets remaining, ~3 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  429fcd26f52d
  b0a32c86eb31
  609d82a7ebae
  228c06deef46
  $ sl bisect -g      # -> update to rev 9
  Testing changeset 3c77083deb4a (5 changesets remaining, ~2 tests)
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -s      # -> update to rev 15
  Testing changeset 857b178a7cf3 (5 changesets remaining, ~2 tests)
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(ignored)'
  $ sl bisect -b
  The first bad revision is:
  commit:      857b178a7cf3
  user:        test
  date:        Thu Jan 01 00:00:15 1970 +0000
  summary:     merge 10,13
  
  Revisions omitted due to the skip option:
  commit:      3c77083deb4a
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     9
  
  commit:      429fcd26f52d
  user:        test
  date:        Thu Jan 01 00:00:10 1970 +0000
  summary:     merge 6,9
  
  commit:      b0a32c86eb31
  user:        test
  date:        Thu Jan 01 00:00:13 1970 +0000
  summary:     13
  $ sl log -q -r 'bisect(range)'
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  $ sl log -q -r 'bisect(ignored)'

complex bisect test 4

first good revision is 17
15,16 are skipped an might be the first good revisions as well

  $ sl bisect -r
  $ sl bisect -g 'desc(17)'
  $ sl bisect -b dab8161ac8fcc3eb808566eaf0641410a54606a8    # -> update to rev 10
  Testing changeset b0a32c86eb31 (8 changesets remaining, ~3 tests)
  2 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -b      # -> update to rev 13
  Testing changeset 429fcd26f52d (5 changesets remaining, ~2 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl bisect -b      # -> update to rev 15
  Testing changeset 857b178a7cf3 (3 changesets remaining, ~1 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  228c06deef46
  $ sl bisect -s      # -> update to rev 16
  Testing changeset 609d82a7ebae (3 changesets remaining, ~1 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  228c06deef46
  $ sl bisect -s
  The first good revision is:
  commit:      228c06deef46
  user:        test
  date:        Thu Jan 01 00:00:17 1970 +0000
  summary:     17
  
  Revisions omitted due to the skip option:
  commit:      857b178a7cf3
  user:        test
  date:        Thu Jan 01 00:00:15 1970 +0000
  summary:     merge 10,13
  
  commit:      609d82a7ebae
  user:        test
  date:        Thu Jan 01 00:00:16 1970 +0000
  summary:     16
  $ sl log -q -r 'bisect(range)'
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46

test unrelated revs:

  $ sl bisect --reset
  $ sl bisect -b 50c76098bbf264a3c9408288f17423717fab2745
  $ sl bisect -g 'desc(14)'
  abort: starting revisions are not directly related
  [255]
  $ sl log -q -r 'bisect(range)'
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  50c76098bbf2
  faa450606157
  $ sl bisect --reset

end at merge: 17 bad, 11 good (but 9 is first bad)

  $ sl bisect -r
  $ sl bisect -b 'desc(17)'
  $ sl bisect -g 'desc(11)'
  Testing changeset b0a32c86eb31 (5 changesets remaining, ~2 tests)
  3 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(ignored)'
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  3c77083deb4a
  429fcd26f52d
  $ sl bisect -g
  Testing changeset 857b178a7cf3 (3 changesets remaining, ~1 tests)
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bisect -b
  The first bad revision is:
  commit:      857b178a7cf3
  user:        test
  date:        Thu Jan 01 00:00:15 1970 +0000
  summary:     merge 10,13
  
  Not all ancestors of this changeset have been checked.
  Use bisect --extend to continue the bisection from
  the common ancestor, dab8161ac8fc.
  $ sl log -q -r 'bisect(range)'
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  dab8161ac8fc
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b
  $ sl log -q -r 'bisect(untested)'
  $ sl log -q -r 'bisect(ignored)'
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  3c77083deb4a
  429fcd26f52d
  $ sl bisect --extend
  Extending search to changeset dab8161ac8fc
  2 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(untested)'
  $ sl log -q -r 'bisect(ignored)'
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  3c77083deb4a
  429fcd26f52d
  $ sl bisect -g # dab8161ac8fc
  Testing changeset 3c77083deb4a (3 changesets remaining, ~1 tests)
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(untested)'
  3c77083deb4a
  429fcd26f52d
  $ sl log -q -r 'bisect(ignored)'
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  $ sl log -q -r 'bisect(goods)'
  33b1f9bc8bc5
  4ca5088da217
  dab8161ac8fc
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  $ sl log -q -r 'bisect(bads)'
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b
  $ sl bisect -b
  The first bad revision is:
  commit:      3c77083deb4a
  user:        test
  date:        Thu Jan 01 00:00:09 1970 +0000
  summary:     9
  
  $ sl log -q -r 'bisect(range)'
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  dab8161ac8fc
  3c77083deb4a
  429fcd26f52d
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b
  $ sl log -q -r 'bisect(untested)'
  $ sl log -q -r 'bisect(ignored)'
  051e12f87bf1
  0950834f0a9c
  5c668c22234f
  385a529b6670
  a214d5d3811a
  $ sl log -q -r 'bisect(goods)'
  33b1f9bc8bc5
  4ca5088da217
  dab8161ac8fc
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  $ sl log -q -r 'bisect(bads)'
  3c77083deb4a
  429fcd26f52d
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b

user adds irrelevant but consistent information (here: -g 2) to bisect state

  $ sl bisect -r
  $ sl bisect -b b0a32c86eb31bca576abd0b987b80b03a460a940
  $ sl bisect -g dab8161ac8fcc3eb808566eaf0641410a54606a8
  Testing changeset 82ca6f06eccd (3 changesets remaining, ~1 tests)
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(untested)'
  82ca6f06eccd
  9f259202bbe7
  $ sl bisect -g 051e12f87bf18d19c780aadf5a08554100cfa07a
  Testing changeset 82ca6f06eccd (3 changesets remaining, ~1 tests)
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl log -q -r 'bisect(untested)'
  82ca6f06eccd
  9f259202bbe7
  $ sl bisect -b
  The first bad revision is:
  commit:      82ca6f06eccd
  user:        test
  date:        Thu Jan 01 00:00:11 1970 +0000
  summary:     11
  
  $ sl log -q -r 'bisect(range)'
  dab8161ac8fc
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  $ sl log -q -r 'bisect(pruned)'
  33b1f9bc8bc5
  4ca5088da217
  051e12f87bf1
  dab8161ac8fc
  82ca6f06eccd
  9f259202bbe7
  b0a32c86eb31
  faa450606157
  857b178a7cf3
  609d82a7ebae
  228c06deef46
  d42e18c7bc9b
  $ sl log -q -r 'bisect(untested)'
