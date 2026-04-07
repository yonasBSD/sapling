
#require git no-eden


  $ newclientrepo
  $ sl log -r . -T '{nodescheme}\n'
  hg

  $ cd
  $ sl init --git git
  $ cd git
  $ sl log -r . -T '{nodescheme}\n'
  git
