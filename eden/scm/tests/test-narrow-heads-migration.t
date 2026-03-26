
#require no-eden


  $ export HGIDENTITY=sl
  $ eagerepo
Test migration between narrow-heads and non-narrow-heads

  $ enable amend
  $ setconfig experimental.narrow-heads=true visibility.enabled=true mutation.record=true mutation.enabled=true experimental.evolution= remotenames.rename.default=remote

  $ newrepo
  $ drawdag << 'EOS'
  > B C
  > |/
  > A
  > EOS

Make 'B' public, and 'C' draft.

  $ sl debugremotebookmark master $B
  $ sl phase $B
  112478962961147124edd43549aedd1a335e44bf: public
  $ sl phase $C
  dc0947a82db884575bb76ea10ac97b08536bfa03: draft

Migrate down.

  $ setconfig experimental.narrow-heads=false

 (Test if the repo is locked, the auto migration is skipped)
  $ EDENSCM_TEST_PRETEND_LOCKED=lock sl phase $B
  112478962961147124edd43549aedd1a335e44bf: public

  $ sl phase $B
  112478962961147124edd43549aedd1a335e44bf: public
  $ sl phase $C
  dc0947a82db884575bb76ea10ac97b08536bfa03: draft
  $ drawdag << 'EOS'
  > D
  > |
  > A
  > EOS
  $ sl phase $D
  b18e25de2cf5fc4699a029ed635882849e53ef73: draft

Migrate up.

  $ setconfig experimental.narrow-heads=true
  $ sl phase $B
  112478962961147124edd43549aedd1a335e44bf: public
  $ sl phase $C
  dc0947a82db884575bb76ea10ac97b08536bfa03: draft
  $ sl phase $D
  b18e25de2cf5fc4699a029ed635882849e53ef73: draft

Test (legacy) secret commit migration.

  $ newrepo
  $ setconfig experimental.narrow-heads=false

  $ drawdag << 'EOS'
  >   D
  >   |
  > M C
  > |/
  > | B
  > |/
  > A
  > EOS
  $ sl debugremotebookmark master $M
  $ sl debugmakepublic $M
  $ sl phase --force --draft $C
  $ sl phase --force --secret $D+$B
  $ sl hide $D -q

Migrate up.

  $ setconfig experimental.narrow-heads=true
  $ sl log -G -T '{desc} {phase}'
  o  M public
  │
  │ o  C draft
  ├─╯
  │ o  B draft
  ├─╯
  o  A public
  
Migrate down.

  $ rm .sl/store/phaseroots
  $ setconfig experimental.narrow-heads=false
  $ sl log -G -T '{desc} {phase}'
  o  M public
  │
  │ o  C draft
  ├─╯
  │ o  B draft
  ├─╯
  o  A public
  
 (Check: D is invisible)
