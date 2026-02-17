/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

//! Implement traits defined by other crates.

use std::sync::Arc;

use anyhow::Result;
use blob::Blob;
use edenapi_types::FileAuxData;
use format_util::git_sha1_digest;
use format_util::hg_sha1_digest;
use minibytes::Bytes;
use storemodel::BoxIterator;
use storemodel::InsertOpts;
use storemodel::KeyStore;
use storemodel::Kind;
use storemodel::SerializationFormat;
use types::FetchContext;
use types::HgId;
use types::Id20;
use types::Key;
use types::RepoPath;
use types::hgid::NULL_ID;

use crate::scmstore::FileAttributes;
use crate::scmstore::FileStore;

// Wrapper types to workaround Rust's orphan rule.
#[derive(Clone)]
pub struct ArcFileStore(pub Arc<FileStore>);

impl storemodel::KeyStore for ArcFileStore {
    fn get_content_iter(
        &self,
        fctx: FetchContext,
        keys: Vec<Key>,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Blob)>>> {
        let fetched = self.0.fetch(fctx, keys, FileAttributes::PURE_CONTENT);
        let iter = fetched
            .into_iter()
            .map(|result| -> anyhow::Result<(Key, Blob)> {
                let (key, store_file) = result?;
                let content = store_file.file_content()?;
                Ok((key, content))
            });
        Ok(Box::new(iter))
    }

    fn get_local_content(&self, _path: &RepoPath, hgid: HgId) -> anyhow::Result<Option<Blob>> {
        self.0.get_local_content_direct(&hgid)
    }

    fn flush(&self) -> Result<()> {
        FileStore::flush(&self.0)
    }

    fn refresh(&self) -> Result<()> {
        FileStore::refresh(&self.0)
    }

    fn statistics(&self) -> Vec<(String, usize)> {
        FileStore::metrics(&self.0)
    }

    /// Decides whether the store uses git or hg format.
    fn format(&self) -> SerializationFormat {
        self.0.format
    }

    fn insert_data(&self, opts: InsertOpts, path: &RepoPath, data: &[u8]) -> anyhow::Result<HgId> {
        let id = sha1_digest(&opts, data, self.format());

        if opts.read_before_write
            && let Some(l) = &self.0.indexedlog_local
        {
            if l.contains(&id)? {
                return Ok(id);
            }
        }

        let key = Key::new(path.to_owned(), id);
        // PERF: Ideally, there is no need to copy `data`.
        let data = Bytes::copy_from_slice(data);
        self.0.write_nonlfs(key, data, Default::default())?;
        Ok(id)
    }

    fn clone_key_store(&self) -> Box<dyn KeyStore> {
        Box::new(self.clone())
    }
}

impl storemodel::FileStore for ArcFileStore {
    fn get_rename_iter(
        &self,
        keys: Vec<Key>,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Key)>>> {
        let fetched = self.0.fetch(
            FetchContext::default(),
            keys,
            FileAttributes::CONTENT_HEADER,
        );
        let iter = fetched
            .into_iter()
            .filter_map(|result| -> Option<anyhow::Result<(Key, Key)>> {
                (move || -> anyhow::Result<Option<(Key, Key)>> {
                    let (key, store_file) = result?;
                    Ok(store_file.copy_info()?.map(|copy_from| (key, copy_from)))
                })()
                .transpose()
            });
        Ok(Box::new(iter))
    }

    fn get_local_aux(&self, _path: &RepoPath, id: HgId) -> anyhow::Result<Option<FileAuxData>> {
        self.0.get_local_aux_direct(&id)
    }

    fn get_aux_iter(
        &self,
        fctx: FetchContext,
        keys: Vec<Key>,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, FileAuxData)>>> {
        let fetched = self.0.fetch(fctx, keys, FileAttributes::AUX);
        let iter = fetched
            .into_iter()
            .map(|entry| -> anyhow::Result<(Key, FileAuxData)> {
                let (key, store_file) = entry?;
                let aux = store_file.aux_data()?;
                Ok((key, aux))
            });
        Ok(Box::new(iter))
    }

    fn clone_file_store(&self) -> Box<dyn storemodel::FileStore> {
        Box::new(self.clone())
    }
}

pub(crate) fn sha1_digest(opts: &InsertOpts, data: &[u8], format: SerializationFormat) -> Id20 {
    match format {
        SerializationFormat::Hg => {
            let p1 = opts.parents.first().copied().unwrap_or(NULL_ID);
            let p2 = opts.parents.get(1).copied().unwrap_or(NULL_ID);
            hg_sha1_digest(data, &p1, &p2)
        }
        SerializationFormat::Git => {
            let kind = match opts.kind {
                Kind::File => "blob",
                Kind::Tree => "tree",
            };
            git_sha1_digest(data, kind)
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;
    use std::sync::Arc;

    use storemodel::KeyStore;
    use tempfile::TempDir;
    use types::RepoPathBuf;

    use super::*;
    use crate::ToKeys;
    use crate::indexedlogdatastore::IndexedLogHgIdDataStore;
    use crate::indexedlogdatastore::IndexedLogHgIdDataStoreConfig;
    use crate::indexedlogutil::StoreType;
    use crate::scmstore::FileStore;

    #[test]
    fn test_insert_data_read_before_write() {
        let tempdir = TempDir::new().unwrap();
        let config = IndexedLogHgIdDataStoreConfig {
            max_log_count: None,
            max_bytes_per_log: None,
            max_bytes: None,
            btrfs_compression: false,
        };
        let indexedlog = Arc::new(
            IndexedLogHgIdDataStore::new(
                &BTreeMap::<&str, &str>::new(),
                &tempdir,
                &config,
                StoreType::Rotated,
                SerializationFormat::Hg,
            )
            .unwrap(),
        );

        let mut file_store = FileStore::empty();
        file_store.indexedlog_local = Some(indexedlog.clone());
        let arc_file_store = ArcFileStore(Arc::new(file_store));

        let path = RepoPathBuf::from_string("test/file.txt".to_string()).unwrap();
        let data = b"test content";

        // First insert without read_before_write
        let opts = InsertOpts::default();
        let id1 = arc_file_store.insert_data(opts, &path, data).unwrap();

        // Verify the data is in the store
        assert!(indexedlog.contains(&id1).unwrap());
        assert_eq!(indexedlog.to_keys().len(), 1);

        // Second insert with read_before_write=true should return same id without writing again
        let opts = InsertOpts {
            read_before_write: true,
            ..Default::default()
        };
        let id2 = arc_file_store.insert_data(opts, &path, data).unwrap();

        // Should return the same id
        assert_eq!(id1, id2);

        // Crucially, there should still be only 1 entry (no duplicate write)
        assert_eq!(indexedlog.to_keys().len(), 1);

        // Verify that without read_before_write, we would get a duplicate
        let opts = InsertOpts {
            read_before_write: false,
            ..Default::default()
        };
        let id3 = arc_file_store.insert_data(opts, &path, data).unwrap();
        assert_eq!(id1, id3);

        // Now there should be 2 entries (duplicate was written)
        assert_eq!(indexedlog.to_keys().len(), 2);
    }
}
