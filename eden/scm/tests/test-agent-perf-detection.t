  $ enable rebase
  $ setconfig agent.max-commit-fetch-count=6
  $ setconfig experimental.commit-fetch-batch-size=2
  $ export CODING_AGENT_METADATA=id=test_agent

Repo setup

  $ newclientrepo
  $ drawdag <<'EOS'
  > A01..A99
  > EOS
  $ sl go -q $A99

Requesting commits <= limit should succeed:

  $ sl log -r 'desc(A)' -T '{desc}\n' -l 6
  A01
  A02
  A03
  A04
  A05
  A06

One more than the limit still succeeds because the check fires after each
batch (batch_size=2), so the abort triggers at the end of the batch that
crosses the limit, not at the exact count:

  $ sl log -r 'desc(A)' -T '{desc}\n' -l 7
  A01
  A02
  A03
  A04
  A05
  A06
  A07

Requesting enough commits to complete a full batch past the limit triggers
the abort:

  $ sl log -r 'desc(A)' -T '{desc}\n' -l 8
  abort: revset query scanned over 6 commits
  (run 'sl help agent performance' for guidance.)
  [255]

Test --user:

  $ sl log --user test -T '{desc}\n' -l 2
  A99
  A98
  $ sl log --user test -T '{desc}\n' -l 8
  abort: revset query scanned over 6 commits
  (run 'sl help agent performance' for guidance.)
  [255]

Test --keyword:

  $ sl log --keyword A -T '{desc}\n' -l 2
  A99
  A98
  $ sl log --keyword A -T '{desc}\n' -l 8
  abort: revset query scanned over 6 commits
  (run 'sl help agent performance' for guidance.)
  [255]

Test --date:
  $ sl log --date '1970-01-01' -T '{desc}\n' -l 2
  A99
  A98
  $ sl log --date '1970-01-01' -T '{desc}\n' -l 8
  abort: revset query scanned over 6 commits
  (run 'sl help agent performance' for guidance.)
  [255]

Disable the detection:

  $ sl log -r 'desc(A)' -T '{desc}\n' -l 8 --config agent.max-commit-fetch-count=0
  A01
  A02
  A03
  A04
  A05
  A06
  A07
  A08
