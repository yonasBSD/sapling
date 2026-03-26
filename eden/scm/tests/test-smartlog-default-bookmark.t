  $ export HGIDENTITY=sl
  $ enable smartlog

  $ newclientrepo
  $ touch foo
  $ sl ci -Aqm foo
  $ setconfig remotenames.selectivepulldefault=banana
  $ sl push -q --to banana --create
  $ echo foo > foo
  $ sl ci -qm bar
  $ sl push -q --to apple --create
  $ sl pull -qB apple

We show selectivepulldefault by default:
  $ sl log -r 'interestingmaster()' -T '{remotebookmarks}\n'
  remote/banana
