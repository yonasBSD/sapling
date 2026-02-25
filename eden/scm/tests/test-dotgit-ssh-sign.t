#require git no-eden ssh-keygen

  $ . $TESTDIR/git.sh

Prepare an SSH key for signing:

  $ export HGUSER='Test User <test@example.com>'
  $ ssh-keygen -t ed25519 -f "$TESTTMP/test_sign_key" -N "" -q
  $ setconfig signing.backend=ssh signing.key="$TESTTMP/test_sign_key" ui.allowemptycommit=true

Prepare a git repo:

  $ git init -q -b main git-repo
  $ cd git-repo

Commit via sl with SSH signing:

  $ sl commit -m init

Verify signature:

  $ printf "%s %s\n" "test@example.com" "$(cat $TESTTMP/test_sign_key.pub)" > "$TESTTMP/allowed_signers"
  $ git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile="$TESTTMP/allowed_signers" verify-commit $(sl log -r. -T '{node}')
  Good "git" signature for test@example.com with * key * (glob)

Edit commit message:

  $ sl metaedit -m init2

Verify signature after metaedit:

  $ git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile="$TESTTMP/allowed_signers" verify-commit $(sl log -r. -T '{node}')
  Good "git" signature for test@example.com with * key * (glob)
