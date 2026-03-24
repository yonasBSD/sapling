
#require no-eden

#inprocess-hg-incompatible

  $ export HGIDENTITY=sl
  $ eagerepo
Using 'ext.' prefix triggers the warning.

  $ sl init --config extensions.ext.rebase=
  'ext' prefix in [extensions] config section is deprecated.
  (hint: replace 'ext.rebase' with 'rebase')

If the location of the config is printed.
Despite the warning, the extension is still loaded.

  $ setconfig extensions.ext.rebase=
  $ sl rebase -s 'tip-tip' -d 'tip'
  'ext' prefix in [extensions] config section is deprecated.
  (hint: replace 'ext.rebase' with 'rebase' at $TESTTMP/.sl/config:2)
  empty "source" revision set - nothing to rebase
