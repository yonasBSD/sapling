# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

setup configuration
  $ setup_common_config

  $ testtool_drawdag -R repo --derive-all << 'EOF' 2>/dev/null
  > A
  > # modify: A "dir/subdir/file1" "content1"
  > # modify: A "dir/subdir/file2" "content2"
  > # modify: A "dir/subdir/nested/file3" "content3"
  > # modify: A "dir/other_file" "other"
  > # modify: A "root_file" "root"
  > # bookmark: A main
  > EOF

Test 1: Basic directory deletion
  $ mononoke_admin commit -R repo delete-directory --parent $A --path dir/subdir | tee $TESTTMP/delete_output
  Deleting 3 files under 'dir/subdir'
  * (glob)

  $ DELETE_CS_ID=$(tail -1 $TESTTMP/delete_output)

Verify the deletion commit
  $ mononoke_admin fetch -R repo -i "$DELETE_CS_ID"
  BonsaiChangesetId: * (glob)
  Author: svcscm
  Message: Deleted via mononoke_admin commit delete-directory
  FileChanges:
  	 REMOVED: dir/subdir/file1
  	 REMOVED: dir/subdir/file2
  	 REMOVED: dir/subdir/nested/file3
  

Test 2: Error case - non-existent path
  $ mononoke_admin commit -R repo delete-directory --parent $A --path nonexistent
  Error: Path 'nonexistent' does not exist in the given commit
  [1]

Test 3: Error case - path is a file, not a directory
  $ mononoke_admin commit -R repo delete-directory --parent $A --path root_file
  Error: Path 'root_file' is a file, not a directory
  [1]
