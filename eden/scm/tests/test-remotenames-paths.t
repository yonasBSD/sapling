
#require no-eden


  $ eagerepo

Init a repo

  $ sl init pathsrepo
  $ cd pathsrepo

Check that a new path can be added

  $ sl paths -a yellowbrickroad yellowbrickroad
  $ sl paths -a stairwaytoheaven stairwaytoheaven
  $ sl paths
  stairwaytoheaven = $TESTTMP/pathsrepo/stairwaytoheaven
  yellowbrickroad = $TESTTMP/pathsrepo/yellowbrickroad

Check that a repo can be deleted

  $ sl paths -d yellowbrickroad
  $ sl paths
  stairwaytoheaven = $TESTTMP/pathsrepo/stairwaytoheaven

Delete .sl/config fil

  $ rm .sl/config

Non-existence of config file does not change behavior:

  $ sl paths -d stairwaytoheaven

Check that a path can be added when no .sl/config file exists

  $ sl paths -a yellowbrickroad yellowbrickroad
  $ sl paths
  yellowbrickroad = $TESTTMP/pathsrepo/yellowbrickroad

Helpful error with wrong args:

  $ sl paths -a banana
  abort: invalid URL - invoke as 'sl paths -a NAME URL'
  [255]

  $ sl paths -a banana too many
  abort: invalid URL - invoke as 'sl paths -a NAME URL'
  [255]
