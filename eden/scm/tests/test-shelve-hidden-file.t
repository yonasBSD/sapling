
  $ export HGIDENTITY=sl
  $ enable shelve

Use wrong formatted '._*' files to mimic the binary files created by MacOS:

  $ newclientrepo simple << 'EOS'
  > d
  > | c
  > | |
  > | b
  > |/
  > a
  > EOS
#if no-eden
TODO(sggutier): This should work on EdenFS, but there seems to be a bug in EagerRepo's implementation
  $ sl goto $c
  pulling 'a82ac2b3875752239b995aabd5b4e9712db0bc9e' from 'test:simple_server'
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ echo c > c.txt
  $ sl add c.txt
  $ sl shelve
  shelved as default
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved

  $ echo 'wrong format' >> .sl/shelved/._default.oshelve
  $ echo 'wrong format' >> .sl/shelved/._default.patch

  $ sl log -r 'shelved()' -T '{desc}'
  shelve changes to: c (no-eol)
#endif
