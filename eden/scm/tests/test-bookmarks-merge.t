
#require no-eden


# init

  $ eagerepo
  $ sl init repo
  $ cd repo
  $ echo a > a
  $ sl add a
  $ sl commit -m'a'
  $ echo b > b
  $ sl add b
  $ sl commit -m'b'
  $ sl up -C 'desc(a)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo c > c
  $ sl add c
  $ sl commit -m'c'

# test merging of diverged bookmarks
  $ sl bookmark -r 'desc(b)' "c@diverge"
  $ sl bookmark -r 'desc(b)' b
  $ sl bookmark c
  $ sl bookmarks
     b                         d2ae7f538514
   * c                         d36c0562f908
     c@diverge                 d2ae7f538514
  $ sl merge "c@diverge"
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl commit -m'merge'
  $ sl bookmarks
     b                         d2ae7f538514
   * c                         b8f96cf4688b

  $ sl up -C 'desc(merge)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (leaving bookmark c)
  $ echo d > d
  $ sl add d
  $ sl commit -m'd'

  $ sl up -C 'desc(merge)'
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo e > e
  $ sl add e
  $ sl commit -m'e'
  $ sl up -C 'max(desc(e))'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl bookmark e
  $ sl bookmarks
     b                         d2ae7f538514
     c                         b8f96cf4688b
   * e                         26bee9c5bcf3

# the picked side is bookmarked

  $ sl up -C 'desc(d)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark e)
  $ sl merge
  abort: heads are bookmarked - please merge with an explicit rev
  (run 'sl heads' to see all heads)
  [255]

# our revision is bookmarked

  $ sl up -C e
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark e)
  $ sl merge
  abort: no matching bookmark to merge - please merge with an explicit rev or bookmark
  (run 'sl heads' to see all heads)
  [255]

# merge bookmark heads

  $ sl up -C 'desc(d)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark e)
  $ echo f > f
  $ sl commit -Am "f"
  adding f
  $ sl bookmarks -r 'desc(d)' "e@diverged"
  $ sl up -q -C "e@diverged"
  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl parents
  commit:      a0546fcfe0fb
  bookmark:    e@diverged
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     d
  
  commit:      26bee9c5bcf3
  bookmark:    e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     e
  
  $ sl up -C e
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (activating bookmark e)
  $ sl bookmarks
     b                         d2ae7f538514
     c                         b8f96cf4688b
   * e                         26bee9c5bcf3
     e@diverged                a0546fcfe0fb
  $ sl merge
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  (branch merge, don't forget to commit)
  $ sl commit -m'merge'
  $ sl bookmarks
     b                         d2ae7f538514
     c                         b8f96cf4688b
   * e                         ca784329f0ba

# test warning when all heads are inactive bookmarks

  $ sl up -C 'desc(f)'
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  (leaving bookmark e)
  $ echo g > g
  $ sl commit -Am 'g'
  adding g
  $ sl bookmark -i g
  $ sl bookmarks
     b                         d2ae7f538514
     c                         b8f96cf4688b
     e                         ca784329f0ba
     g                         04dd21731d95
  $ sl heads
  commit:      04dd21731d95
  bookmark:    g
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     g
  
  commit:      ca784329f0ba
  bookmark:    e
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     merge
  
  $ sl merge
  abort: heads are bookmarked - please merge with an explicit rev
  (run 'sl heads' to see all heads)
  [255]
