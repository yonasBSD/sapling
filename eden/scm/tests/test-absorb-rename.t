
#require no-eden


  $ setconfig devel.segmented-changelog-rev-compat=true
  $ eagerepo
  $ configure mutation-norecord
  $ enable absorb
  $ setconfig diff.git=1

  $ sedi() { # workaround check-code
  > pattern="$1"
  > shift
  > for i in "$@"; do
  >     sed "$pattern" "$i" > "$i".tmp
  >     mv "$i".tmp "$i"
  > done
  > }

rename a to b, then b to a

  $ sl init repo1
  $ cd repo1

  $ echo 1 > a
  $ sl ci -A a -m 1
  $ sl mv a b
  $ echo 2 >> b
  $ sl ci -m 2
  $ sl mv b a
  $ echo 3 >> a
  $ sl ci -m 3

  $ sl annotate -ncf a
  0 eff892de26ec a: 1
  1 bf56e1f4f857 b: 2
  2 0b888b00216c a: 3

  $ sedi 's/$/a/' a
  $ sl absorb -aq

  $ sl status

  $ sl annotate -ncf a
  3 45a8a8907761 a: 1a
  4 8123dbcf2e51 b: 2a
  5 fe42bff0979f a: 3a

when the first changeset is public

  $ sl debugmakepublic -r 'max(desc(1))'

  $ sedi 's/a/A/' a

  $ sl absorb -aq

  $ sl diff
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,3 +1,3 @@
  -1a
  +1A
   2A
   3A

copy a to b

  $ cd ..
  $ sl init repo2
  $ cd repo2

  $ echo 1 > a
  $ sl ci -A a -m 1
  $ sl cp a b
  $ echo 2 >> b
  $ sl ci -m 2

  $ sl log -T '{node|short} {desc}\n'
  17b72129ab68 2
  eff892de26ec 1

  $ sedi 's/$/a/' a
  $ sedi 's/$/b/' b

  $ sl absorb -aq

  $ sl diff
  diff --git a/b b/b
  --- a/b
  +++ b/b
  @@ -1,2 +1,2 @@
  -1
  +1b
   2b

copy b to a

  $ cd ..
  $ sl init repo3
  $ cd repo3

  $ echo 1 > b
  $ sl ci -A b -m 1
  $ sl cp b a
  $ echo 2 >> a
  $ sl ci -m 2

  $ sl log -T '{node|short} {desc}\n'
  e62c256d8b24 2
  55105f940d5c 1

  $ sedi 's/$/a/' a
  $ sedi 's/$/a/' b

  $ sl absorb -aq

  $ sl diff
  diff --git a/a b/a
  --- a/a
  +++ b/a
  @@ -1,2 +1,2 @@
  -1
  +1a
   2a

"move" b to both a and c, follow a - sorted alphabetically

  $ cd ..
  $ sl init repo4
  $ cd repo4

  $ echo 1 > b
  $ sl ci -A b -m 1
  $ sl cp b a
  $ sl cp b c
  $ sl rm b
  $ echo 2 >> a
  $ echo 3 >> c
  $ sl commit -m cp

  $ sl log -T '{node|short} {desc}\n'
  366daad8e679 cp
  55105f940d5c 1

  $ sedi 's/$/a/' a
  $ sedi 's/$/c/' c

  $ sl absorb -aq

  $ sl log -G -p -T '{node|short} {desc}\n'
  @  10d2b0b4c50c cp
  │  diff --git a/b b/a
  │  rename from b
  │  rename to a
  │  --- a/b
  │  +++ b/a
  │  @@ -1,1 +1,2 @@
  │   1a
  │  +2a
  │  diff --git a/b b/c
  │  copy from b
  │  copy to c
  │  --- a/b
  │  +++ b/c
  │  @@ -1,1 +1,2 @@
  │  -1a
  │  +1
  │  +3c
  │
  o  8125da0f2fc2 1
     diff --git a/b b/b
     new file mode 100644
     --- /dev/null
     +++ b/b
     @@ -0,0 +1,1 @@
     +1a
run absorb again would apply the change to c

  $ sl absorb -aq

  $ sl log -G -p -T '{node|short} {desc}\n'
  @  306537321486 cp
  │  diff --git a/b b/a
  │  rename from b
  │  rename to a
  │  --- a/b
  │  +++ b/a
  │  @@ -1,1 +1,2 @@
  │   1a
  │  +2a
  │  diff --git a/b b/c
  │  copy from b
  │  copy to c
  │  --- a/b
  │  +++ b/c
  │  @@ -1,1 +1,2 @@
  │  -1a
  │  +1c
  │  +3c
  │
  o  8125da0f2fc2 1
     diff --git a/b b/b
     new file mode 100644
     --- /dev/null
     +++ b/b
     @@ -0,0 +1,1 @@
     +1a
"move" b to a, c and d, follow d if a gets renamed to e, and c is deleted

  $ cd ..
  $ sl init repo5
  $ cd repo5

  $ echo 1 > b
  $ sl ci -A b -m 1
  $ sl cp b a
  $ sl cp b c
  $ sl cp b d
  $ sl rm b
  $ echo 2 >> a
  $ echo 3 >> c
  $ echo 4 >> d
  $ sl commit -m cp
  $ sl mv a e
  $ sl rm c
  $ sl commit -m mv

  $ sl log -T '{node|short} {desc}\n'
  49911557c471 mv
  7bc3d43ede83 cp
  55105f940d5c 1

  $ sedi 's/$/e/' e
  $ sedi 's/$/d/' d

  $ sl absorb -aq

  $ sl diff
  diff --git a/e b/e
  --- a/e
  +++ b/e
  @@ -1,2 +1,2 @@
  -1
  +1e
   2e

  $ sl log -G -p -T '{node|short} {desc}\n'
  @  89a575169d85 mv
  │  diff --git a/c b/c
  │  deleted file mode 100644
  │  --- a/c
  │  +++ /dev/null
  │  @@ -1,2 +0,0 @@
  │  -1
  │  -3
  │  diff --git a/a b/e
  │  rename from a
  │  rename to e
  │
  o  d996d2ad951a cp
  │  diff --git a/b b/a
  │  rename from b
  │  rename to a
  │  --- a/b
  │  +++ b/a
  │  @@ -1,1 +1,2 @@
  │  -1d
  │  +1
  │  +2e
  │  diff --git a/b b/c
  │  copy from b
  │  copy to c
  │  --- a/b
  │  +++ b/c
  │  @@ -1,1 +1,2 @@
  │  -1d
  │  +1
  │  +3
  │  diff --git a/b b/d
  │  copy from b
  │  copy to d
  │  --- a/b
  │  +++ b/d
  │  @@ -1,1 +1,2 @@
  │   1d
  │  +4d
  │
  o  97758c741207 1
     diff --git a/b b/b
     new file mode 100644
     --- /dev/null
     +++ b/b
     @@ -0,0 +1,1 @@
     +1d
