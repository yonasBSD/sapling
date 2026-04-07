
#require no-eden

#inprocess-hg-incompatible

  $ eagerepo
  $ enable github
  $ enable ghstack

Build up a non-github repo

  $ sl init repo
  $ cd repo
  $ echo a > a1
  $ sl ci -Am addfile
  adding a1

Confirm 'github_repo' does not error
  $ sl log -r. -T '{github_repo}'
  False (no-eol)

Confirm pull request creation will fail
  $ sl pr submit
  abort: * (glob)
  [255]
  $ sl ghstack
  hint[ghstack-deprecation]: 
  ┌───────────────────────────────────────────────────────────────┐
  │ Native ghstack command in Sapling will be removed.            │
  │ Please use `.git` mode [1] and upstream ghstack [2] instead.  │
  │ [1]: https://sapling-scm.com/docs/git/git_support_modes/      │
  │ [2]: https://github.com/ezyang/ghstack                        │
  └───────────────────────────────────────────────────────────────┘
  abort: * (glob)
  [255]
