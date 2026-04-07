#modern-config-incompatible

#require no-eden


  $ configure modern

  $ newserver master
  $ setconfig smallcommitmetadata.entrylimit=6
  $ echo "a" > a ; sl add a ; sl commit -qAm a
  $ echo "b" > b ; sl add b ; sl commit -qAm b
  $ echo "c" > c ; sl add c ; sl commit -qAm c
  $ sl log
  commit:      177f92b77385
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     c
  
  commit:      d2ae7f538514
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     b
  
  commit:      cb9a9f314b8b
  user:        test
  date:        Thu Jan 01 00:00:00 1970 +0000
  summary:     a
  


Add some metadata
  $ sl debugsmallcommitmetadata -r cb9a9f314b8b -c toomanyondisk willbetruncated
  $ sl debugsmallcommitmetadata -r cb9a9f314b8b -c acategory avalue_willbeevicted
  $ sl debugsmallcommitmetadata -r d2ae7f538514 -c bcategory bvalue
  $ sl debugsmallcommitmetadata -r 177f92b77385 -c ccategory cvalue
  $ sl debugsmallcommitmetadata -r cb9a9f314b8b -c abccategory avalue
  $ sl debugsmallcommitmetadata -r d2ae7f538514 -c abccategory bvalue

Verify basic and JSON output:
  $ sl debugsmallcommitmetadata
  Found the following entries:
  cb9a9f314b8b toomanyondisk: 'willbetruncated'
  cb9a9f314b8b acategory: 'avalue_willbeevicted'
  d2ae7f538514 bcategory: 'bvalue'
  177f92b77385 ccategory: 'cvalue'
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  $ sl debugsmallcommitmetadata --template json
  [
   {
    "category": "toomanyondisk",
    "node": "cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b",
    "value": "willbetruncated"
   },
   {
    "category": "acategory",
    "node": "cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b",
    "value": "avalue_willbeevicted"
   },
   {
    "category": "bcategory",
    "node": "d2ae7f538514cd87c17547b0de4cea71fe1af9fb",
    "value": "bvalue"
   },
   {
    "category": "ccategory",
    "node": "177f92b773850b59254aa5e923436f921b55483b",
    "value": "cvalue"
   },
   {
    "category": "abccategory",
    "node": "cb9a9f314b8b07ba71012fcdbc544b5a4d82ff5b",
    "value": "avalue"
   },
   {
    "category": "abccategory",
    "node": "d2ae7f538514cd87c17547b0de4cea71fe1af9fb",
    "value": "bvalue"
   }
  ]

Verify that the limit is enforced properly.
  $ setconfig smallcommitmetadata.entrylimit=5
  $ sl debugsmallcommitmetadata
  Found the following entries:
  cb9a9f314b8b acategory: 'avalue_willbeevicted'
  d2ae7f538514 bcategory: 'bvalue'
  177f92b77385 ccategory: 'cvalue'
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  $ sl debugsmallcommitmetadata -r 177f92b77385 -c abccategory cvalue
  Evicted the following entry to stay below limit:
  cb9a9f314b8b acategory: 'avalue_willbeevicted'
  $ sl debugsmallcommitmetadata
  Found the following entries:
  d2ae7f538514 bcategory: 'bvalue'
  177f92b77385 ccategory: 'cvalue'
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  177f92b77385 abccategory: 'cvalue'

Verify that reads work correctly
  $ sl debugsmallcommitmetadata -r d2ae7f538514 -c bcategory
  Found the following entry:
  d2ae7f538514 bcategory: 'bvalue'
  $ sl debugsmallcommitmetadata -r cb9a9f314b8b
  Found the following entries:
  cb9a9f314b8b abccategory: 'avalue'
  $ sl debugsmallcommitmetadata -c ccategory
  Found the following entries:
  177f92b77385 ccategory: 'cvalue'
  $ sl debugsmallcommitmetadata -c abccategory
  Found the following entries:
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  177f92b77385 abccategory: 'cvalue'

Verify that deletes work correctly
  $ sl debugsmallcommitmetadata -d -r d2ae7f538514 -c bcategory
  Deleted the following entry:
  d2ae7f538514 bcategory: 'bvalue'
  $ sl debugsmallcommitmetadata
  Found the following entries:
  177f92b77385 ccategory: 'cvalue'
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  177f92b77385 abccategory: 'cvalue'
  $ sl debugsmallcommitmetadata -d -c abccategory
  Deleted the following entries:
  cb9a9f314b8b abccategory: 'avalue'
  d2ae7f538514 abccategory: 'bvalue'
  177f92b77385 abccategory: 'cvalue'
  $ sl debugsmallcommitmetadata
  Found the following entries:
  177f92b77385 ccategory: 'cvalue'
  $ sl debugsmallcommitmetadata -d -r 177f92b77385
  Deleted the following entries:
  177f92b77385 ccategory: 'cvalue'
  $ sl debugsmallcommitmetadata
  Found the following entries:
  $ sl debugsmallcommitmetadata -d
  Deleted the following entries:
  $ sl debugsmallcommitmetadata
  Found the following entries:
