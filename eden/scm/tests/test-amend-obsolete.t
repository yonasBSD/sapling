#require no-eden

  $ enable amend

Create a commit and amend it to produce an obsolete predecessor:

  $ newclientrepo
  $ echo a > a
  $ sl add a
  $ sl commit -m "original commit"
  $ sl log -r . -T '{node|short}\n'
  87ce07975dfa
  $ sl amend -m "amended commit"
  $ sl amend -m "amended commit again"
  $ sl debugmutation -r "all()"
   *  58bce2fd05ef3404d5fb87d8fa94a8e4fdfc331e amend by test at 1970-01-01T00:00:00 from:
      4ccb9bde2b77c1549b886c8f34d05caeccc3e298 amend by test at 1970-01-01T00:00:00 from:
      87ce07975dfa08ef73b58855de6c810a6c7c20a5

Go back to the obsolete commit:

  $ sl go 87ce07975dfa
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved

Agent: amend on obsolete commit should abort:

  $ echo b > b
  $ sl add b
  $ CODING_AGENT_METADATA=id=test_agent sl amend -m "agent amend"
  abort: changing an old version of a commit will diverge your stack:
  - 87ce07975dfa -> 58bce2fd05ef (rewrite)
  (run 'sl sl' for the latest commit graph view)
  [255]

Agent: commit --amend on obsolete commit should abort:

  $ CODING_AGENT_METADATA=id=test_agent sl commit --amend -m "agent commit --amend"
  abort: changing an old version of a commit will diverge your stack:
  - 87ce07975dfa -> 58bce2fd05ef (rewrite)
  (run 'sl sl' for the latest commit graph view)
  [255]

Interactive user choosing No should abort:

  $ sl amend --config ui.interactive=true -m "user amend no" <<EOF
  > n
  > EOF
  warning: changing an old version of a commit will diverge your stack:
  - 87ce07975dfa -> 58bce2fd05ef (rewrite)
  proceed with amend (Yn)?  n
  abort: aborted by user
  [255]

Interactive user choosing Yes should proceed:

  $ sl amend --config ui.interactive=true -m "user amend yes" <<EOF
  > y
  > EOF
  warning: changing an old version of a commit will diverge your stack:
  - 87ce07975dfa -> 58bce2fd05ef (rewrite)
  proceed with amend (Yn)?  y

Should not block SL_AUTOMATION

  $ sl go 87ce07975dfa
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ echo c > c
  $ sl add c
  $ SL_AUTOMATION=true sl am -m "automation script amend"

Config override should allow amending obsolete commits:

  $ sl go 87ce07975dfa
  0 files updated, 0 files merged, * files removed, 0 files unresolved (glob)
  $ echo d > d
  $ sl add d
  $ CODING_AGENT_METADATA=id=test_agent sl amend --config commit.reject-modifying-obsolete=False -m "config override amend"
