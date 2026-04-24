
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
FIXME: Hook silently doesn't run because "and repo is not None" guard skips pyhook when repo is None.
  $ cat > $TESTTMP/clonehook.py << 'EOF'
  > import os
  > def myhook(**kwargs):
  >     with open(os.path.join(os.environ.get("TESTTMP", "/tmp"), "pyhook_ran"), "w") as f:
  >         f.write("yes\n")
  > EOF
  $ sl clone -Uq test:e1 repo2 --config "hooks.pre-clone.myhook=python:base64:$(base64 -w0 $TESTTMP/clonehook.py):myhook" --config clone.use-rust=false
  loading pre-clone.myhook hook failed: [Errno 2] $ENOENT$: 'base64:aW1wb3J0IG9zCmRlZiBteWhvb2soKiprd2FyZ3MpOgogICAgd2l0aCBvcGVuKG9zLnBhdGguam9pbihvcy5lbnZpcm9uLmdldCgiVEVTVFRNUCIsICIvdG1wIiksICJweWhvb2tfcmFuIiksICJ3IikgYXMgZjoKICAgICAgICBmLndyaXRlKCJ5ZXNcbiIpCg=='
  abort: $ENOENT$: base64:aW1wb3J0IG9zCmRlZiBteWhvb2soKiprd2FyZ3MpOgogICAgd2l0aCBvcGVuKG9zLnBhdGguam9pbihvcy5lbnZpcm9uLmdldCgiVEVTVFRNUCIsICIvdG1wIiksICJweWhvb2tfcmFuIiksICJ3IikgYXMgZjoKICAgICAgICBmLndyaXRlKCJ5ZXNcbiIpCg==
  [255]
