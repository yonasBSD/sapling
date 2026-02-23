
#require no-eden


  $ eagerepo
Setup

  $ enable fbcodereview smartlog
  $ setconfig extensions.arcconfig="$TESTDIR/../sapling/ext/extlib/phabricator/arcconfig.py"
  $ hg init repo
  $ cd repo
  $ touch foo
  $ hg ci -qAm 'Differential Revision: https://phabricator.fb.com/D1'

With an invalid arc configuration

  $ hg log -T '{phabstatus}\n' -r .
  arcconfig configuration problem. No diff information can be provided.
  Error info: no .arcconfig found
  Error

Configure arc...

  $ echo '{}' > .arcrc
  $ echo '{"config" : {"default" : "https://a.com/api"}, "hosts" : {"https://a.com/api/" : { "user" : "testuser", "oauth" : "garbage_cert"}}}' > .arcconfig

And now with bad responses:

  $ cat > $TESTTMP/mockduit << EOF
  > [{}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Error talking to phabricator. No diff information can be provided.
  Error info: Unexpected graphql response format
  Error

  $ cat > $TESTTMP/mockduit << EOF
  > [{"errors": [{"message": "failed, yo"}]}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Error talking to phabricator. No diff information can be provided.
  Error info: failed, yo
  Error

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": null}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Error talking to phabricator. No diff information can be provided.
  Error info: Unexpected graphql response format
  Error

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": null}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Error talking to phabricator. No diff information can be provided.
  Error info: Unexpected graphql response format
  Error

Missing status field is treated as an error
  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "created_time": 0, "updated_time": 2}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Error talking to phabricator. No diff information can be provided.
  Error info: Unexpected graphql response format for D1
  Error

If the diff is landing, show "Landing" in place of the status name

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_JOB_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Landing

If the diff has landed, but Phabricator hasn't parsed it yet, show "Committing"
in place of the status name

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_RECENTLY_SUCCEEDED",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Committing

If the diff recently failed to land, show "Recently Failed to Land"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_RECENTLY_FAILED",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Recently Failed to Land

If the diff is enqueued for landing, show "Land Enqueued"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_ENQUEUED",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Land Enqueued

If the diff is scheduled for landing, show "Land Scheduled"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_SCHEDULED",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Land Scheduled

If the diff land is on hold, show "Land On Hold"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "LAND_ON_HOLD",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Land On Hold

If the diff land was cancelled, show "Land Cancelled"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "LAND_CANCELLED",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Land Cancelled

If the diff needs a final review, show "Needs Final Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": true,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs Final Review

If the diff is accepted but awaiting extra reviewer (CRS second review), show "Needs Extra Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "AWAITING", "type": "CRS_SECOND_REVIEW"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs Extra Review

If the diff is accepted but awaiting steward review, show "Needs Steward Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "AWAITING", "type": "STEWARD_REVIEW"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs Steward Review

If the diff is accepted but awaiting ACL reviewer, show "Needs ACL Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "AWAITING", "type": "REVIEWERS_ACL"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs ACL Review

If the diff is accepted but awaiting DRS reviewer, show "Needs DRS Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "AWAITING", "type": "DRS_REVIEWER"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs DRS Review

If the diff is accepted but awaiting CRS recommended reviewer, show "Needs CRS Review"

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "AWAITING", "type": "CRS_RECOMMENDED_REVIEWER"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs CRS Review

If required_reviewers_info status is REVIEWED, show the base status (Accepted)

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": {"overall_status": "REVIEWED", "type": "CRS_SECOND_REVIEW"}}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Accepted

If required_reviewers_info is null, show the base status

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Accepted",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED",
  >    "required_reviewers_info": null}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Accepted

And finally, the success case

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Needs Review",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg log -T '{phabstatus}\n' -r .
  Needs Review

Make sure the code works without the smartlog extensions

  $ cat > $TESTTMP/mockduit << EOF
  > [{"data": {"query": [{"results": {"nodes": [
  >   {"number": 1, "diff_status_name": "Needs Review",
  >    "created_time": 0, "updated_time": 2, "is_landing": false,
  >    "land_job_status": "NO_LAND_RUNNING",
  >    "needs_final_review_status": "NOT_NEEDED"}
  > ]}}]}}]
  > EOF
  $ HG_ARC_CONDUIT_MOCK=$TESTTMP/mockduit hg --config 'extensions.smartlog=!' log -T '{phabstatus}\n' -r .
  Needs Review

Make sure the template keywords are documented correctly

  $ hg help templates | egrep 'phabstatus|syncstatus'
      phabstatus    String. Return the diff approval status for a given hg rev
      syncstatus    String. Return whether the local revision is in sync with

Make sure we get decent error messages when .arcrc is missing credential
information.  We intentionally do not use HG_ARC_CONDUIT_MOCK for this test,
so it tries to parse the (empty) arc config files.

  $ echo '{}' > .arcrc
  $ echo '{}' > .arcconfig
  $ hg log -T '{phabstatus}\n' -r .
  arcconfig configuration problem. No diff information can be provided.
  Error info: arcrc is missing user credentials. Use "jf authenticate" to fix, or ensure you are prepping your arcrc properly.
  Error

Make sure we get an error message if .arcrc is not proper JSON (for example
due to trailing commas). We do not use HG_ARC_CONDUIT_MOCK for this test,
in order for it to parse the badly formatted arc config file.

  $ echo '{,}' > ../.arcrc
  $ hg log -T '{phabstatus}\n' -r .
  arcconfig configuration problem. No diff information can be provided.
  Error info: Configuration file $TESTTMP/.arcrc is not a proper JSON file.
  Error
