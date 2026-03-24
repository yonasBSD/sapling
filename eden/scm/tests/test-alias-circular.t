
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Alias can override builtin commands.

  $ newrepo
  $ setconfig alias.log="log -T 'x\n'"
  $ sl log -r null
  x

Alias can override a builtin command to another builtin command.

  $ newrepo
  $ setconfig alias.log=id
  $ sl log -r null
  000000000000

Alias can refer to another alias. Order does not matter.

  $ newrepo
  $ cat >> .sl/config <<EOF
  > [alias]
  > a = b
  > b = log -r null -T 'x\n'
  > c = b
  > EOF
  $ sl a
  x
  $ sl c
  x

Alias cannot form a cycle.

  $ newrepo
  $ cat >> .sl/config << EOF
  > [alias]
  > c = a
  > a = b
  > b = c
  > logwithsuffix = logwithsuff
  > log = log
  > EOF

  $ sl a
  abort: circular alias: a
  [255]
  $ sl b
  abort: circular alias: b
  [255]
  $ sl c
  abort: circular alias: c
  [255]
  $ sl log -r null -T 'x\n'
  x

Prefix matching is disabled in aliases

  $ sl logwithsuffix
  unknown command 'logwithsuff'
  (use 'sl help' to get help)
  [255]
