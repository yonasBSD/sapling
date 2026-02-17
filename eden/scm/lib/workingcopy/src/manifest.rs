/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::sync::Arc;

use anyhow::Result;
use manifest::FileMetadata;
use manifest::FileType;
use manifest::Manifest;
use status::Status;
use storemodel::FileStore;
use storemodel::InsertOpts;
use types::RepoPathBuf;
use vfs::VFS;

use crate::metadata::Metadata;

/// Applies uncommitted changes from status to a manifest.
///
/// This function takes a base manifest and a Status instance (as returned by
/// `WorkingCopy::status()`), reads file content from the VFS, computes file nodes
/// by inserting into the file store, and updates the manifest.
pub fn apply_status<M: Manifest>(
    manifest: &mut M,
    status: &Status,
    vfs: &VFS,
    file_store: &Arc<dyn FileStore>,
) -> Result<()> {
    // TODO: support copies

    // Process removals first.
    // This ensures we handle cases like a file being replaced by a directory.
    for path in status.removed() {
        manifest.remove(path)?;
    }

    // Process added and modified files.
    for path in status.added().chain(status.modified()) {
        let metadata = insert_file(path, vfs, file_store)?;
        manifest.insert(path.clone(), metadata)?;
    }

    Ok(())
}

/// Reads a file from VFS, inserts it into the file store, and returns the resulting FileMetadata.
fn insert_file(
    path: &RepoPathBuf,
    vfs: &VFS,
    file_store: &Arc<dyn FileStore>,
) -> Result<FileMetadata> {
    let (content, fs_meta) = vfs.read_with_metadata(path)?;

    // Convert std::fs::Metadata to our Metadata type which knows about VFS capabilities.
    let meta: Metadata = fs_meta.into();

    let file_type = if meta.is_symlink(vfs) {
        FileType::Symlink
    } else if meta.is_executable(vfs) {
        FileType::Executable
    } else {
        FileType::Regular
    };

    // Insert the file into the store to compute its hgid.
    // TODO: support parents
    let opts = InsertOpts::default();
    let hgid = file_store.insert_file(opts, path, &content)?;
    Ok(FileMetadata::new(hgid, file_type))
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use format_util;
    use manifest::FileType;
    use manifest_tree::TreeManifest;
    use manifest_tree::testutil::TestStore;
    use manifest_tree::testutil::make_tree_manifest;
    use pathmatcher::AlwaysMatcher;
    use status::StatusBuilder;
    use types::HgId;
    use types::testutil::*;

    use super::*;

    fn list_files(manifest: &TreeManifest) -> Vec<String> {
        let mut files: Vec<_> = manifest
            .files(AlwaysMatcher::new())
            .map(|f| f.unwrap().path.into_string())
            .collect();
        files.sort();
        files
    }

    #[test]
    fn test_apply_status_with_removals() {
        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(
            tree_store,
            &[("file1", "10"), ("file2", "20"), ("file3", "30")],
        );
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        // Create a temp directory for VFS (won't actually be used for removals)
        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new(tmp.path().to_path_buf()).unwrap();

        let status = StatusBuilder::new()
            .removed(vec![repo_path_buf("file1"), repo_path_buf("file2")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        assert_eq!(list_files(&manifest), vec!["file3"]);
    }

    #[test]
    fn test_apply_status_with_additions() {
        use std::fs;

        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(tree_store, &[("existing", "10")]);
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new_destructive(tmp.path().to_path_buf()).unwrap();

        // Create files in the temp directory
        fs::write(tmp.path().join("new_file"), b"new content").unwrap();
        fs::create_dir_all(tmp.path().join("dir")).unwrap();
        fs::write(tmp.path().join("dir/nested"), b"nested content").unwrap();

        let status = StatusBuilder::new()
            .added(vec![repo_path_buf("new_file"), repo_path_buf("dir/nested")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        assert_eq!(
            list_files(&manifest),
            vec!["dir/nested", "existing", "new_file"]
        );

        // Verify files were inserted into the store with correct content hashes
        let new_file_meta = manifest.get_file(repo_path("new_file")).unwrap().unwrap();
        let expected_hgid =
            format_util::hg_sha1_digest(b"new content", HgId::null_id(), HgId::null_id());
        assert_eq!(new_file_meta.hgid, expected_hgid);

        let nested_meta = manifest.get_file(repo_path("dir/nested")).unwrap().unwrap();
        let expected_hgid =
            format_util::hg_sha1_digest(b"nested content", HgId::null_id(), HgId::null_id());
        assert_eq!(nested_meta.hgid, expected_hgid);
    }

    #[test]
    fn test_apply_status_with_modifications() {
        use std::fs;

        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(tree_store, &[("file1", "10"), ("file2", "20")]);
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new_destructive(tmp.path().to_path_buf()).unwrap();

        // Create files with modified content
        fs::write(tmp.path().join("file1"), b"modified content 1").unwrap();
        fs::write(tmp.path().join("file2"), b"modified content 2").unwrap();

        let status = StatusBuilder::new()
            .modified(vec![repo_path_buf("file1"), repo_path_buf("file2")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        // Verify manifest was updated with new hgids matching content hashes
        let file1_meta = manifest.get_file(repo_path("file1")).unwrap().unwrap();
        let expected_hgid =
            format_util::hg_sha1_digest(b"modified content 1", HgId::null_id(), HgId::null_id());
        assert_eq!(file1_meta.hgid, expected_hgid);

        let file2_meta = manifest.get_file(repo_path("file2")).unwrap().unwrap();
        let expected_hgid =
            format_util::hg_sha1_digest(b"modified content 2", HgId::null_id(), HgId::null_id());
        assert_eq!(file2_meta.hgid, expected_hgid);
    }

    #[test]
    fn test_apply_status_mixed_operations() {
        use std::fs;

        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(
            tree_store,
            &[("keep", "10"), ("modify", "20"), ("remove", "30")],
        );
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new_destructive(tmp.path().to_path_buf()).unwrap();

        // Create files for additions and modifications
        fs::write(tmp.path().join("new_file"), b"new content").unwrap();
        fs::write(tmp.path().join("modify"), b"modified content").unwrap();

        let status = StatusBuilder::new()
            .added(vec![repo_path_buf("new_file")])
            .modified(vec![repo_path_buf("modify")])
            .removed(vec![repo_path_buf("remove")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        assert_eq!(list_files(&manifest), vec!["keep", "modify", "new_file"]);
    }

    #[test]
    fn test_apply_status_empty_status() {
        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(tree_store, &[("file", "10")]);
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new(tmp.path().to_path_buf()).unwrap();

        let status = StatusBuilder::new().build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        assert_eq!(list_files(&manifest), vec!["file"]);
    }

    #[cfg(unix)]
    #[test]
    fn test_apply_status_with_executable_file() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(tree_store, &[]);
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new_destructive(tmp.path().to_path_buf()).unwrap();

        // Create an executable file
        let exec_path = tmp.path().join("script.sh");
        fs::write(&exec_path, b"#!/bin/bash\necho hello").unwrap();
        fs::set_permissions(&exec_path, fs::Permissions::from_mode(0o755)).unwrap();

        let status = StatusBuilder::new()
            .added(vec![repo_path_buf("script.sh")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        let meta = manifest.get_file(repo_path("script.sh")).unwrap().unwrap();
        assert_eq!(meta.file_type, FileType::Executable);
    }

    #[cfg(unix)]
    #[test]
    fn test_apply_status_with_symlink() {
        use std::os::unix::fs;

        let tree_store = Arc::new(TestStore::new());
        let mut manifest = make_tree_manifest(tree_store, &[]);
        let file_store: Arc<dyn FileStore> = Arc::new(TestStore::new());

        let tmp = tempfile::tempdir().unwrap();
        let vfs = VFS::new_destructive(tmp.path().to_path_buf()).unwrap();

        // Create a symlink
        let link_path = tmp.path().join("link");
        fs::symlink("target", &link_path).unwrap();

        let status = StatusBuilder::new()
            .added(vec![repo_path_buf("link")])
            .build();

        apply_status(&mut manifest, &status, &vfs, &file_store).unwrap();

        let meta = manifest.get_file(repo_path("link")).unwrap().unwrap();
        assert_eq!(meta.file_type, FileType::Symlink);

        // Verify the symlink target was stored
        let expected_hgid =
            format_util::hg_sha1_digest(b"target", HgId::null_id(), HgId::null_id());
        assert_eq!(meta.hgid, expected_hgid);
    }
}
