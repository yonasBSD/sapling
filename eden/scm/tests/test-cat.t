
#require no-eden


  $ setconfig devel.segmented-changelog-rev-compat=true
  $ newrepo repo
  $ echo 0 > a
  $ echo 0 > b
  $ sl ci -A -m m
  adding a
  adding b
  $ sl rm a
  $ sl cat a
  0
  $ echo 1 > b
  $ sl ci -m m
  $ echo 2 > b
  $ sl cat -r 9e16845058722867cade99889e97fc5ef64ddf5a a
  0
  $ sl cat -r 9e16845058722867cade99889e97fc5ef64ddf5a b
  0
  $ sl cat -r 'max(desc(m))' a
  [1]
  $ sl cat -r 'max(desc(m))' b
  1

Test multiple files

  $ echo 3 > c
  $ sl ci -Am addmore c
  $ sl cat b c
  1
  3
  $ sl cat .
  1
  3
  $ sl cat . c
  1
  3

Test fileset

  $ sl cat 'set:not(b) or a'
  3
  $ sl cat 'set:c or b'
  1
  3

  $ mkdir tmp
  $ sl cat --output tmp/HH_%H c
  $ sl cat --output tmp/RR_%R c
  $ sl cat --output tmp/h_%h c
  $ sl cat --output tmp/r_%r c
  $ sl cat --output tmp/%s_s c
  $ sl cat --output tmp/d_%d%% c
  $ sl cat --output tmp/%p_p c
  $ sl log -r . --template "{node|short}\n"
  45116003780e
  $ f -r tmp
  tmp: directory with 7 files
  tmp/HH_45116003780e3678b333fb2c99fa7d559c8457e9
  tmp/RR_2
  tmp/c_p
  tmp/c_s
  tmp/d_.%
  tmp/h_45116003780e
  tmp/r_2

Test template output

  $ sl --cwd tmp cat ../b ../c -T '== {path} ({abspath}) ==\n{data}'
  == ../b (b) ==
  1
  == ../c (c) ==
  3

  $ sl cat b c -Tjson --output -
  [
   {
    "abspath": "b",
    "data": "1\n",
    "path": "b"
   },
   {
    "abspath": "c",
    "data": "3\n",
    "path": "c"
   }
  ]

  $ sl cat b c -Tjson --output 'tmp/%p.json'
  $ cat tmp/b.json
  [
   {
    "abspath": "b",
    "data": "1\n",
    "path": "b"
   }
  ]
  $ cat tmp/c.json
  [
   {
    "abspath": "c",
    "data": "3\n",
    "path": "c"
   }
  ]

Test working directory

  $ echo b-wdir > b
  $ sl cat -r 'wdir()' b
  b-wdir

Environment variables are not visible by default

  $ PATTERN='t4' sl log -r '.' -T "{ifcontains('PATTERN', envvars, 'yes', 'no')}\n"
  no

Environment variable visibility can be explicit

  $ PATTERN='t4' sl log -r '.' -T "{envvars % '{key} -> {value}\n'}" \
  >                 --config "experimental.exportableenviron=PATTERN"
  PATTERN -> t4

Test behavior of output when directory structure does not already exist

  $ mkdir foo
  $ echo a > foo/a
  $ sl add foo/a
  $ sl commit -qm "add foo/a"
  $ sl cat --output "output/%p" foo/a
  $ cat output/foo/a
  a
