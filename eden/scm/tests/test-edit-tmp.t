
#require no-eden


  $ eagerepo
  $ newrepo
  $ setconfig ui.allowemptycommit=1
  $ enable amend

  $ HGEDITOR=true sl commit -m 1 -e
  $ HGEDITOR=true sl commit --amend -m 2 -e
  $ HGEDITOR='echo 3 >' sl metaedit

All 3 files are here:

  $ python << EOF
  > import os
  > names = os.listdir('.sl/edit-tmp')
  > print(names)
  > for name in names:
  >     os.utime(os.path.join('.sl/edit-tmp', name), (0, 0)) 
  > EOF
  ['*', '*', '*'] (glob)

  $ HGEDITOR=true sl commit -m 4 -e

Those files will be cleaned up since they have ancient mtime:

  $ python << EOF
  > import os
  > print(os.listdir('.sl/edit-tmp'))
  > EOF
  ['*'] (glob)

Verify that a folder in .sl/edit-tmp doesn't crash hg:

  $ mkdir .sl/edit-tmp/foo
  $ HGEDITOR=true sl commit -m 5 -e
