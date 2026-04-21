/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use anyhow::Error;
use anyhow::Result;
use fbinit::FacebookInit;
use fixtures::Linear;
use fixtures::TestRepoFixture;
use mononoke_macros::mononoke;
use mononoke_types::DateTime;
use tests_utils::CreateCommitContext;

use crate::CoreContext;
use crate::FingerprintVersion;
use crate::Mononoke;

/// Decode a hex string into bytes for expected hash comparisons.
fn from_hex(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

#[mononoke::fbinit_test]
async fn test_content_fingerprint_same_tree_different_metadata(
    fb: FacebookInit,
) -> Result<(), Error> {
    let ctx = CoreContext::test_mock(fb);
    let (repo, _commits, _dag) = Linear::get_repo_and_dag(fb).await;

    let root_id = CreateCommitContext::new_root(&ctx, &repo)
        .add_file("a", "hello")
        .commit()
        .await?;

    let cs_id_1 = CreateCommitContext::new(&ctx, &repo, vec![root_id])
        .set_author("alice")
        .set_author_date(DateTime::from_timestamp(1000000, 0).unwrap())
        .set_message("first")
        .add_file("b", "world")
        .commit()
        .await?;

    let cs_id_2 = CreateCommitContext::new(&ctx, &repo, vec![root_id])
        .set_author("bob")
        .set_author_date(DateTime::from_timestamp(2000000, 0).unwrap())
        .set_message("second")
        .add_file("b", "world")
        .commit()
        .await?;

    let mononoke = Mononoke::new_test(vec![("test".to_string(), repo)]).await?;
    let repo_ctx = mononoke
        .repo(ctx.clone(), "test")
        .await?
        .expect("repo exists")
        .build()
        .await?;

    let cs_1 = repo_ctx
        .changeset(cs_id_1)
        .await?
        .expect("changeset exists");
    let cs_2 = repo_ctx
        .changeset(cs_id_2)
        .await?
        .expect("changeset exists");

    let fp_1 = cs_1.content_fingerprint(FingerprintVersion::V1).await?;
    let fp_2 = cs_2.content_fingerprint(FingerprintVersion::V1).await?;

    let expected = from_hex("e7d50f33bfabb947b126c74cf56951014be9de433cc6bb880de7baf96cc1e958");
    assert_eq!(
        fp_1, expected,
        "Fingerprint should match the expected ContentManifestId blake2 hash"
    );
    assert_eq!(
        fp_1, fp_2,
        "Same file tree should produce the same fingerprint regardless of metadata"
    );

    Ok(())
}

#[mononoke::fbinit_test]
async fn test_content_fingerprint_different_trees(fb: FacebookInit) -> Result<(), Error> {
    let ctx = CoreContext::test_mock(fb);
    let (repo, _commits, _dag) = Linear::get_repo_and_dag(fb).await;

    let root_id = CreateCommitContext::new_root(&ctx, &repo)
        .add_file("a", "hello")
        .commit()
        .await?;

    let cs_id_1 = CreateCommitContext::new(&ctx, &repo, vec![root_id])
        .add_file("b", "x")
        .commit()
        .await?;

    let cs_id_2 = CreateCommitContext::new(&ctx, &repo, vec![root_id])
        .add_file("b", "y")
        .commit()
        .await?;

    let mononoke = Mononoke::new_test(vec![("test".to_string(), repo)]).await?;
    let repo_ctx = mononoke
        .repo(ctx.clone(), "test")
        .await?
        .expect("repo exists")
        .build()
        .await?;

    let cs_1 = repo_ctx
        .changeset(cs_id_1)
        .await?
        .expect("changeset exists");
    let cs_2 = repo_ctx
        .changeset(cs_id_2)
        .await?
        .expect("changeset exists");

    let fp_1 = cs_1.content_fingerprint(FingerprintVersion::V1).await?;
    let fp_2 = cs_2.content_fingerprint(FingerprintVersion::V1).await?;

    assert_eq!(
        fp_1,
        from_hex("ac3d7f7d6776b657d8d46160212a48915014f4357eb8917ccab0a4f3f3479ca9"),
        "Fingerprint for tree with file b='x'"
    );
    assert_eq!(
        fp_2,
        from_hex("57d4f0e450c7e20e43fe6bda5261f8f769b7aa183e108009198f6b6d91595bc4"),
        "Fingerprint for tree with file b='y'"
    );

    Ok(())
}

#[mononoke::fbinit_test]
async fn test_content_fingerprint_empty_tree(fb: FacebookInit) -> Result<(), Error> {
    let ctx = CoreContext::test_mock(fb);
    let (repo, _commits, _dag) = Linear::get_repo_and_dag(fb).await;

    let root_id = CreateCommitContext::new_root(&ctx, &repo).commit().await?;

    let mononoke = Mononoke::new_test(vec![("test".to_string(), repo)]).await?;
    let repo_ctx = mononoke
        .repo(ctx.clone(), "test")
        .await?
        .expect("repo exists")
        .build()
        .await?;

    let cs = repo_ctx
        .changeset(root_id)
        .await?
        .expect("changeset exists");
    let fp = cs.content_fingerprint(FingerprintVersion::V1).await?;

    assert_eq!(
        fp,
        from_hex("d91fa09362fcac4ce6633c92a4e0b4ea3b2823ac45de48a68da32a4d65939b04"),
        "Empty tree should have a stable fingerprint"
    );

    Ok(())
}
