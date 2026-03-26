#modern-config-incompatible

#require execbit no-eden
  $ export HGIDENTITY=sl
  $ setconfig experimental.nativecheckout=true
  $ setconfig commands.update.check=none

  $ newserver server

  $ rm -rf a
  $ newremoterepo a

  $ echo foo > foo
  $ sl ci -qAm0
  $ echo toremove > toremove
  $ echo todelete > todelete
  $ chmod +x foo toremove todelete
  $ sl ci -qAm1

Test that local removed/deleted, remote removed works with flags
  $ sl rm toremove
  $ rm todelete
  $ sl co -q 'desc(0)'

  $ echo dirty > foo
  $ sl up -c 'desc(1)'
  abort: uncommitted changes
  [255]
  $ sl up -q 'desc(1)'
  $ cat foo
  dirty
  $ sl st -A
  M foo
  C todelete
  C toremove

Validate update of standalone execute bit change:

  $ sl up -C 'desc(0)'
  1 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ chmod -x foo
  $ sl ci -m removeexec
  nothing changed
  [1]
  $ sl up -C 'desc(0)'
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl up 'desc(1)'
  3 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sl st

  $ cd ..
