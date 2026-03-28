
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo

  $ sl init test
  $ cd test
  $ touch asdf
  $ sl add asdf
  $ HGUSER="My Name <myname@example.com>" sl commit -m commit-1
  $ sl tip
  commit:      53f268a58230
  user:        My Name <myname@example.com>
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit-1
  

  $ echo 1234 > asdf
  $ sl commit -u "foo@bar.com" -m commit-1
  $ sl tip
  commit:      3871b2a9e9bf
  user:        foo@bar.com
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit-1
  
  $ unset HGUSER
  $ echo "[ui]" >> .sl/config
  $ echo "username = foobar <foo@bar.com>" >> .sl/config
  $ echo 12 > asdf
  $ sl commit -m commit-1
  $ sl tip
  commit:      8eeac6695c1c
  user:        foobar <foo@bar.com>
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit-1
  
  $ echo 1 > asdf
  $ sl commit -u "foo@bar.com" -m commit-1
  $ sl tip
  commit:      957606a725e4
  user:        foo@bar.com
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit-1
  
  $ echo 123 > asdf
  $ echo "[ui]" > .sl/config
  $ echo "username = " >> .sl/config
  $ sl commit -m commit-1
  abort: no username supplied
  (use `sl config --user ui.username "First Last <me@example.com>"` to set your username)
  [255]

# test alternate config var

  $ echo 1234 > asdf
  $ echo "[ui]" > .sl/config
  $ echo "user = Foo Bar II <foo2@bar.com>" >> .sl/config
  $ sl commit -m commit-1
  $ sl tip
  commit:      6f24bfb4c617
  user:        Foo Bar II <foo2@bar.com>
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     commit-1
  
# test no .sl/config (uses generated non-interactive username)

  $ echo space > asdf
  $ echo '%unset username' >> .sl/config
  $ echo '%unset user' >> .sl/config
  $ HGPLAIN=1 sl commit -m commit-1
  no username found, using '[^']*' instead (re)

  $ echo space2 > asdf
  $ sl commit -u ' ' -m commit-1
  abort: empty username!
  [255]

# test prompt username and it gets stored

  $ cat > .sl/config <<EOF
  > [ui]
  > askusername = True
  > EOF

  $ echo 12345 > asdf

  $ sl commit --config ui.interactive=True -m ask <<EOF
  > Asked User <ask@example.com>
  > EOF
  enter a commit username: Asked User <ask@example.com>
  $ sl log -r. -T '{author}\n'
  Asked User <ask@example.com>

  $ sl config ui.username --debug
  $TESTTMP/*sapling*: Asked User <ask@example.com> (glob)

# don't add tests here, previous test is unstable

  $ cd ..
