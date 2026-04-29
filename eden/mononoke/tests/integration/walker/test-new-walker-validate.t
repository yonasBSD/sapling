# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

setup configuration
  $ setup_common_config "blob_files"
  $ cd "$TESTTMP"
  $ testtool_drawdag -R repo --derive-all <<EOF
  > C
  > |
  > B
  > |
  > A
  > # bookmark: C master_bookmark
  > EOF
  A=* (glob)
  B=* (glob)
  C=* (glob)

validate, expecting all valid
  $ mononoke_walker validate -I deep -q -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest]
  [INFO] [walker validate{repo=repo}] Performing check types [HgLinkNodePopulated]
  [INFO] [walker validate{repo=repo}] Seen,Loaded: 43,43
  [INFO] [walker validate{repo=repo}] Nodes,Pass,Fail:43,3,0; EdgesChecked:9; CheckType:Pass,Fail Total:3,0 HgLinkNodePopulated:3,0


validate, check route is logged on unexpected error (forced by manually deleting a blob)
  $ ls $TESTTMP/blobstore/blobs | grep -e changeset.blake2
  blob-repo0000.changeset.blake2.* (glob)
  blob-repo0000.changeset.blake2.* (glob)
  blob-repo0000.changeset.blake2.* (glob)

  $ rm -f "$TESTTMP/blobstore/blobs/blob-repo0000.changeset.blake2.$C"

  $ mononoke_walker --scuba-log-file scuba-error.json validate -q -I deep -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest]
  [INFO] [walker validate{repo=repo}] Performing check types [HgLinkNodePopulated]
  [ERROR] Execution error: Could not step to OutgoingEdge { label: BookmarkToChangeset, target: Changeset(ChangesetKey { inner: ChangesetId(Blake2(*)), filenode_known_derived: * }), path: None } via Some(ValidateRoute { src_node: Bookmark(BookmarkKey { name: BookmarkName { bookmark: "master_bookmark" }, category: Branch }), via: [] }) in repo repo (glob)
  
  Caused by:
      changeset.blake2.* is missing (glob)
  Error: Execution failed


Check scuba data is logged for error on step and that it contains message and route info
  $ wc -l < scuba-error.json
  1
  $ jq -r '.int * .normal | [ .check_fail, .check_type, .node_key, .node_type, .repo, .src_node_type, .via_node_type, .walk_type, .error_msg ] | @csv' < scuba-error.json
  1,"missing","changeset.blake2.*","Changeset","repo","Bookmark",,"validate","Could not step to OutgoingEdge { label: BookmarkToChangeset, target: Changeset(ChangesetKey { inner: ChangesetId(Blake2(*)), filenode_known_derived: * }), path: None }, due to Missing(""changeset.blake2.*""), via Some(ValidateRoute { src_node: Bookmark(BookmarkKey { name: BookmarkName { bookmark: ""master_bookmark"" }, category: Branch }), via: [] })" (glob)

repair by re-running testtool_drawdag
  $ testtool_drawdag -R repo --derive-all <<EOF
  > C
  > |
  > B
  > |
  > A
  > # bookmark: C master_bookmark
  > EOF
  A=* (glob)
  B=* (glob)
  C=* (glob)

Remove all filenodes
  $ HG_B=$(sqlite3 "$TESTTMP/monsql/sqlite_dbs" "SELECT hex(hg_cs_id) FROM bonsai_hg_mapping WHERE hex(bcs_id) = upper('$B')")
  $ sqlite3 "$TESTTMP/monsql/sqlite_dbs" "DELETE FROM filenodes where linknode=x'$HG_B'";

validate, expecting validation fails
  $ mononoke_walker --scuba-log-file scuba.json validate -q -I deep -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest]
  [INFO] [walker validate{repo=repo}] Performing check types [HgLinkNodePopulated]
  [WARN] [walker validate{repo=repo}] Validation failed: *hg_link_node_populated* (glob)
  [INFO] [walker validate{repo=repo}] Seen,Loaded: 42,42
  [INFO] [walker validate{repo=repo}] Nodes,Pass,Fail:42,2,1; EdgesChecked:7; CheckType:Pass,Fail Total:2,1 HgLinkNodePopulated:2,1

Check scuba data
  $ wc -l < scuba.json
  1
  $ jq -r '.int * .normal | [ .check_fail, .check_type, .node_key, .node_path, .node_type, .repo, .src_node_key, .src_node_path, .src_node_type, .via_node_key, .via_node_path, .via_node_type, .walk_type ] | @csv' < scuba.json | sort
  1,"hg_link_node_populated","hgfilenode.sha1.35e7525ce3a48913275d7061dd9a867ffef1e34d","B","HgFileNode","repo","hgmanifest.sha1.*","(none)","HgManifest","hgchangeset.sha1.*",,"HgChangeset","validate" (glob)

repair by re-deriving filenodes
  $ mononoke_admin derived-data -R repo derive --rederive -T filenodes -B master_bookmark

validate, expecting all valid, this time checking marker types as well
  $ mononoke_walker validate -q -I deep -I marker -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, ChangesetToPhaseMapping, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest, PhaseMapping]
  [INFO] [walker validate{repo=repo}] Performing check types [ChangesetPhaseIsPublic, HgLinkNodePopulated]
  [INFO] [walker validate{repo=repo}] Seen,Loaded: 46,46
  [INFO] [walker validate{repo=repo}] Nodes,Pass,Fail:46,6,0; EdgesChecked:12; CheckType:Pass,Fail Total:6,0 ChangesetPhaseIsPublic:3,0 HgLinkNodePopulated:3,0

Remove the phase information, linknodes already point to them
  $ sqlite3 "$TESTTMP/monsql/sqlite_dbs" "DELETE FROM phases where repo_id >= 0";

validate, expect no failures on phase info, as the commits are still public, just not marked as so in the phases table
  $ mononoke_walker validate -q -I deep -I marker -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, ChangesetToPhaseMapping, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest, PhaseMapping]
  [INFO] [walker validate{repo=repo}] Performing check types [ChangesetPhaseIsPublic, HgLinkNodePopulated]
  [INFO] [walker validate{repo=repo}] Seen,Loaded: 46,46
  [INFO] [walker validate{repo=repo}] Nodes,Pass,Fail:46,6,0; EdgesChecked:12; CheckType:Pass,Fail Total:6,0 ChangesetPhaseIsPublic:3,0 HgLinkNodePopulated:3,0

Remove all filenodes for the last commit, validation should succeed (i.e. filenodes were not derived yet)
  $ cd "$TESTTMP"
  $ HG_C=$(sqlite3 "$TESTTMP/monsql/sqlite_dbs" "SELECT hex(hg_cs_id) FROM bonsai_hg_mapping WHERE hex(bcs_id) = upper('$C')")
  $ sqlite3 "$TESTTMP/monsql/sqlite_dbs" "DELETE FROM filenodes where HEX(linknode) like lower('$HG_C')";
  $ mononoke_walker validate -q -I deep -b master_bookmark 2>&1 | grep -vE "(Bytes|Walked)/s"
  [INFO] Walking edge types [AliasContentMappingToFileContent, BonsaiHgMappingToHgChangesetViaBonsai, BookmarkToChangeset, ChangesetToBonsaiHgMapping, ChangesetToBonsaiParent, ChangesetToFileContent, FileContentMetadataV2ToGitSha1Alias, FileContentMetadataV2ToSeededBlake3Alias, FileContentMetadataV2ToSha1Alias, FileContentMetadataV2ToSha256Alias, FileContentToFileContentMetadataV2, HgBonsaiMappingToChangeset, HgChangesetToHgManifest, HgChangesetToHgParent, HgChangesetViaBonsaiToHgChangeset, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgBonsaiMapping, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  [INFO] Walking node types [AliasContentMapping, BonsaiHgMapping, Bookmark, Changeset, FileContent, FileContentMetadataV2, HgBonsaiMapping, HgChangeset, HgChangesetViaBonsai, HgFileEnvelope, HgFileNode, HgManifest]
  [INFO] [walker validate{repo=repo}] Performing check types [HgLinkNodePopulated]
  [INFO] [walker validate{repo=repo}] Seen,Loaded: 37,37
  [INFO] [walker validate{repo=repo}] Nodes,Pass,Fail:37,2,0; EdgesChecked:6; CheckType:Pass,Fail Total:2,0 HgLinkNodePopulated:2,0
