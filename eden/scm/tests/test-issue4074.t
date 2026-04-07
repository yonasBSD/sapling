
#require no-eden


  $ eagerepo
A script to generate nasty diff worst-case scenarios:

  $ cat > s.py <<EOF
  > import random, sys
  > random.seed(int(sys.argv[-1]))
  > for x in range(100000):
  >     print
  >     if random.randint(0, 100) >= 50:
  >         x += 1
  >     print(hex(x))
  > EOF

  $ sl init a
  $ cd a

Check in a big file:

  $ sl debugpython -- ../s.py 1 > a
  $ sl ci -qAm0

Modify it:

  $ sl debugpython -- ../s.py 2 > a

Time a check-in, should never take more than 10 seconds user time:

  $ sl ci --time -m1
  time: real .* secs .user [0-9][.].* sys .* (re)
