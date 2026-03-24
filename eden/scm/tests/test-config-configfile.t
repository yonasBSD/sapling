
#require no-eden

  $ export HGIDENTITY=sl
  $ eagerepo
  $ configure dummyssh modernclient
  $ newclientrepo repo

Empty
  $ sl log --configfile
  sl log: option --configfile requires argument
  (use 'sl log -h' to get help)
  [255]

Simple file
  $ cat >> $TESTTMP/simple.rc <<EOF
  > [mysection]
  > myname = myvalue
  > EOF
  $ sl config --configfile $TESTTMP/simple.rc mysection
  mysection.myname=myvalue

RC file that includes another
  $ cat >> $TESTTMP/include.rc <<EOF
  > [includesection]
  > includename = includevalue
  > EOF
  $ cat >> $TESTTMP/simple.rc <<EOF
  > %include $TESTTMP/include.rc
  > EOF
  $ sl config --configfile $TESTTMP/simple.rc includesection
  includesection.includename=includevalue

Order matters
  $ cat >> $TESTTMP/other.rc <<EOF
  > [mysection]
  > myname = othervalue
  > EOF
  $ sl config --configfile $TESTTMP/other.rc --configfile $TESTTMP/simple.rc mysection
  mysection.myname=myvalue
  $ sl config --configfile $TESTTMP/simple.rc --configfile $TESTTMP/other.rc mysection
  mysection.myname=othervalue

Order relative to --config
  $ sl config --configfile $TESTTMP/simple.rc --config mysection.myname=manualvalue mysection
  mysection.myname=manualvalue

Attribution works
  $ sl config --configfile $TESTTMP/simple.rc mysection --debug
  $TESTTMP/simple.rc:2: mysection.myname=myvalue

Cloning adds --configfile values to .sl/config
  $ cd ..
  $ sl clone -q test:repo_server repo2 --configfile $TESTTMP/simple.rc --configfile $TESTTMP/other.rc
  $ dos2unix repo2/.sl/config
  %include $TESTTMP/simple.rc
  %include $TESTTMP/other.rc
  
  [paths]
  default = test:repo_server
