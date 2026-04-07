
#require no-eden


  $ eagerepo
  $ setconfig devel.segmented-changelog-rev-compat=true
  $ sl init repo
  $ cd repo

  $ echo a > a
  $ sl ci -Ama
  adding a

  $ sl an a
  cb9a9f314b8b: a

  $ sl --config ui.strict=False an a
  cb9a9f314b8b: a

  $ setconfig ui.strict=true

No difference - "an" is an alias

  $ sl an a
  cb9a9f314b8b: a
  $ sl annotate a
  cb9a9f314b8b: a

should succeed - up is an alias, not an abbreviation

  $ sl up tip
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
