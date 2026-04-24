
#require no-eden


  $ configure modern
  $ newremoterepo repo1
  $ setconfig paths.default=test:e1

Show post-clone runs from within the new repo.
  $ cd ..
  $ sl clone -Uq test:e1 repo --config 'hooks.post-clone.foo=touch bar' --config clone.use-rust=false
  $ ls repo
  bar

Base64-encoded python hook during pre-clone (repo is None).
  $ cat > $TESTTMP/clonehook.py << 'EOF'
  > import os
  > def myhook(**kwargs):
  >     with open(os.path.join(os.environ.get("TESTTMP", "/tmp"), "pyhook_ran"), "w") as f:
  >         f.write("yes\n")
  > EOF
  $ sl clone -Uq test:e1 repo2 --config "hooks.pre-clone.myhook=python:base64:$(base64 -w0 $TESTTMP/clonehook.py):myhook" --config clone.use-rust=false
  $ cat $TESTTMP/pyhook_ran
  yes
