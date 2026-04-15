/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::collections::HashMap;

use anyhow::Error;
use anyhow::Result;
use async_trait::async_trait;
use bookmarks::BookmarkKey;
use context::CoreContext;
use mononoke_types::BonsaiChangeset;
use mononoke_types::MPathElement;
use mononoke_types::NonRootMPath;

use crate::ChangesetHook;
use crate::CrossRepoPushSource;
use crate::HookExecution;
use crate::HookRejectionInfo;
use crate::HookRepo;
use crate::PathContent;
use crate::PushAuthoredBy;

const BLOCKED_HOST: &str = "dewey-lfs.vip.facebook.com";

#[derive(Clone, Debug)]
pub struct BlockDeweyLfsUrlHook {}

impl BlockDeweyLfsUrlHook {
    pub fn new() -> Self {
        Self {}
    }
}

#[async_trait]
impl ChangesetHook for BlockDeweyLfsUrlHook {
    async fn run<'this: 'cs, 'ctx: 'this, 'cs, 'repo: 'cs>(
        &'this self,
        ctx: &'ctx CoreContext,
        hook_repo: &'repo HookRepo,
        _bookmark: &BookmarkKey,
        changeset: &'cs BonsaiChangeset,
        _cross_repo_push_source: CrossRepoPushSource,
        _push_authored_by: PushAuthoredBy,
    ) -> Result<HookExecution, Error> {
        let lfsconfig_path: NonRootMPath = MPathElement::new_from_slice(b".lfsconfig")?.into();

        // Check if this changeset touches .lfsconfig
        let touches_lfsconfig = changeset
            .file_changes()
            .any(|(path, _)| *path == lfsconfig_path);

        if !touches_lfsconfig {
            return Ok(HookExecution::Accepted);
        }

        // Fetch the .lfsconfig content at this changeset
        let content_map: HashMap<NonRootMPath, PathContent> = hook_repo
            .find_content_by_changeset_id(
                ctx,
                changeset.get_changeset_id(),
                vec![lfsconfig_path.clone()],
            )
            .await?;

        let content_id = match content_map.get(&lfsconfig_path) {
            Some(PathContent::File(id)) => *id,
            _ => return Ok(HookExecution::Accepted),
        };

        let file_bytes = match hook_repo.get_file_text(ctx, content_id).await? {
            Some(bytes) => bytes,
            None => return Ok(HookExecution::Accepted),
        };

        let config = match gix_config::File::from_bytes_no_includes(
            &file_bytes,
            gix_config::file::Metadata::from(gix_config::Source::Local),
            gix_config::file::init::Options::default(),
        ) {
            Ok(config) => config,
            Err(_) => return Ok(HookExecution::Accepted),
        };

        if let Ok(url) = config.raw_value("lfs.url") {
            let url_str = String::from_utf8_lossy(url.as_ref());
            let lower = url_str.to_ascii_lowercase();
            if lower.contains(BLOCKED_HOST) {
                return Ok(HookExecution::Rejected(HookRejectionInfo::new_long(
                    "The .lfsconfig file must not set lfs.url to dewey-lfs.vip.facebook.com.",
                    format!(
                        "The .lfsconfig file sets lfs.url to \"{}\". \
                         The hardcoded dewey-lfs.vip.facebook.com URL must be removed as part of \
                         the Dewey LFS to Mononoke LFS migration tracked in S629462. \
                         Hardcoding an lfs.url for the internal LFS server is no longer required at Meta. \
                         Please remove the lfs.url setting from .lfsconfig.",
                        url_str,
                    ),
                )));
            }
        }

        Ok(HookExecution::Accepted)
    }
}

#[cfg(test)]
mod tests {
    use fbinit::FacebookInit;
    use hook_manager_testlib::HookTestRepo;
    use mononoke_macros::mononoke;
    use tests_utils::bookmark;
    use tests_utils::drawdag::changes;
    use tests_utils::drawdag::create_from_dag_with_changes;

    use super::*;
    use crate::testlib::test_changeset_hook;

    #[mononoke::fbinit_test]
    async fn test_accepted_when_lfsconfig_not_touched(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file("some_file.txt", "hello"),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        assert_eq!(
            test_changeset_hook(
                &ctx,
                &repo,
                &hook,
                "main",
                changesets["A"],
                CrossRepoPushSource::NativeToThisRepo,
                PushAuthoredBy::User,
            )
            .await?,
            HookExecution::Accepted,
        );
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_accepted_when_lfsconfig_has_no_lfs_url(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(".lfsconfig", "[core]\n\trepositoryformatversion = 0\n"),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        assert_eq!(
            test_changeset_hook(
                &ctx,
                &repo,
                &hook,
                "main",
                changesets["A"],
                CrossRepoPushSource::NativeToThisRepo,
                PushAuthoredBy::User,
            )
            .await?,
            HookExecution::Accepted,
        );
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_accepted_when_lfs_url_is_allowed(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(".lfsconfig", "[lfs]\n\turl = https://lfs.example.com\n"),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        assert_eq!(
            test_changeset_hook(
                &ctx,
                &repo,
                &hook,
                "main",
                changesets["A"],
                CrossRepoPushSource::NativeToThisRepo,
                PushAuthoredBy::User,
            )
            .await?,
            HookExecution::Accepted,
        );
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rejected_when_lfs_url_is_dewey(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(
                    ".lfsconfig",
                    "[lfs]\n\turl = https://dewey-lfs.vip.facebook.com\n",
                ),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        let result = test_changeset_hook(
            &ctx,
            &repo,
            &hook,
            "main",
            changesets["A"],
            CrossRepoPushSource::NativeToThisRepo,
            PushAuthoredBy::User,
        )
        .await?;
        assert!(matches!(result, HookExecution::Rejected(_)));
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rejected_when_lfs_url_is_dewey_with_trailing_slash(
        fb: FacebookInit,
    ) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(
                    ".lfsconfig",
                    "[lfs]\n\turl = https://dewey-lfs.vip.facebook.com/\n",
                ),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        let result = test_changeset_hook(
            &ctx,
            &repo,
            &hook,
            "main",
            changesets["A"],
            CrossRepoPushSource::NativeToThisRepo,
            PushAuthoredBy::User,
        )
        .await?;
        assert!(matches!(result, HookExecution::Rejected(_)));
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rejected_case_insensitive(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(
                    ".lfsconfig",
                    "[lfs]\n\turl = https://Dewey-LFS.VIP.Facebook.com\n",
                ),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        let result = test_changeset_hook(
            &ctx,
            &repo,
            &hook,
            "main",
            changesets["A"],
            CrossRepoPushSource::NativeToThisRepo,
            PushAuthoredBy::User,
        )
        .await?;
        assert!(matches!(result, HookExecution::Rejected(_)));
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rejected_when_lfs_url_is_http_dewey(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(
                    ".lfsconfig",
                    "[lfs]\n\turl = http://dewey-lfs.vip.facebook.com\n",
                ),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        let result = test_changeset_hook(
            &ctx,
            &repo,
            &hook,
            "main",
            changesets["A"],
            CrossRepoPushSource::NativeToThisRepo,
            PushAuthoredBy::User,
        )
        .await?;
        assert!(matches!(result, HookExecution::Rejected(_)));
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_rejected_when_lfs_url_is_dewey_with_path(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(
                    ".lfsconfig",
                    "[lfs]\n\turl = https://dewey-lfs.vip.facebook.com/objects/batch\n",
                ),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        let result = test_changeset_hook(
            &ctx,
            &repo,
            &hook,
            "main",
            changesets["A"],
            CrossRepoPushSource::NativeToThisRepo,
            PushAuthoredBy::User,
        )
        .await?;
        assert!(matches!(result, HookExecution::Rejected(_)));
        Ok(())
    }

    #[mononoke::fbinit_test]
    async fn test_accepted_when_lfsconfig_is_malformed(fb: FacebookInit) -> Result<()> {
        let ctx = CoreContext::test_mock(fb);
        let repo: HookTestRepo = test_repo_factory::build_empty(fb).await?;

        let changesets = create_from_dag_with_changes(
            &ctx,
            &repo,
            r##"
                Z-A
            "##,
            changes! {
                "A" => |c| c.add_file(".lfsconfig", "this is not valid gitconfig {{{{"),
            },
        )
        .await?;
        bookmark(&ctx, &repo, "main")
            .create_publishing(changesets["Z"])
            .await?;

        let hook = BlockDeweyLfsUrlHook::new();
        assert_eq!(
            test_changeset_hook(
                &ctx,
                &repo,
                &hook,
                "main",
                changesets["A"],
                CrossRepoPushSource::NativeToThisRepo,
                PushAuthoredBy::User,
            )
            .await?,
            HookExecution::Accepted,
        );
        Ok(())
    }
}
