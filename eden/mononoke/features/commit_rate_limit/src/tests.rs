/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use blobstore::Loadable;
use bonsai_hg_mapping::BonsaiHgMapping;
use borrowed::borrowed;
use commit_graph::CommitGraph;
use commit_graph::CommitGraphWriter;
use fbinit::FacebookInit;
use filestore::FilestoreConfig;
use mononoke_macros::mononoke;
use mononoke_types::BonsaiChangesetMut;
use mononoke_types::ChangesetId;
use mononoke_types::ContentId;
use mononoke_types::DateTime;
use mononoke_types::FileChange;
use mononoke_types::FileType;
use mononoke_types::GitLfs;
use mononoke_types::NonRootMPath;
use repo_blobstore::RepoBlobstore;
use repo_derived_data::RepoDerivedData;
use repo_identity::RepoIdentity;
use tests_utils::CreateCommitContext;
use tests_utils::bookmark;

use super::*;

// --- Test repo type ---

#[facet::container]
#[derive(Clone)]
struct TestRepo {
    #[facet]
    bookmarks: dyn bookmarks::Bookmarks,

    #[facet]
    repo_blobstore: RepoBlobstore,

    #[facet]
    commit_graph: CommitGraph,

    #[facet]
    commit_graph_writer: dyn CommitGraphWriter,

    #[facet]
    repo_derived_data: RepoDerivedData,

    #[facet]
    repo_identity: RepoIdentity,

    #[facet]
    bonsai_hg_mapping: dyn BonsaiHgMapping,

    #[facet]
    filestore_config: FilestoreConfig,
}

// =========================================================================
// Constants and helpers
// =========================================================================

const ALICE: &str = "Alice <alice@fb.com>";
const BOB: &str = "Bob <bob@fb.com>";

/// The commit message tag used by all tests.
const ELIGIBLE_TAG: &str = "AUTO_APPROVED";

/// The hg_extra key used by tests (for the setup DAG).
const ELIGIBLE_EXTRA: &str = "auto_approved";

fn recent_date() -> DateTime {
    DateTime::now()
}

fn make_config(directories: &[&str], per_user: bool, max_commits: u64) -> CommitRateLimitConfig {
    let dirs = directories.iter().map(|d| d.to_string()).collect();
    CommitRateLimitConfig {
        eligibility_checks: vec![
            EligibilityCheck::CommitMessageTag {
                tag: ELIGIBLE_TAG.to_string(),
            },
            EligibilityCheck::HgExtra {
                key: ELIGIBLE_EXTRA.to_string(),
            },
        ],
        limits: vec![RateLimit {
            window_secs: 3600,
            max_commits,
        }],
        directories: dirs,
        per_user,
    }
}

fn make_changeset(extras: Vec<(&str, &[u8])>, files: Vec<&str>, message: &str) -> BonsaiChangeset {
    let hg_extra = extras
        .into_iter()
        .map(|(k, v)| (k.to_string(), v.to_vec()))
        .collect();
    let file_changes = files
        .into_iter()
        .enumerate()
        .map(|(i, path)| {
            let mut content_id_bytes = [0u8; 32];
            content_id_bytes[0] = (i + 1) as u8;
            (
                NonRootMPath::new(path).expect("test path must be valid"),
                FileChange::tracked(
                    ContentId::from_bytes(content_id_bytes).expect("failed to load content id"),
                    FileType::Regular,
                    10,
                    None,
                    GitLfs::FullContent,
                ),
            )
        })
        .collect();
    BonsaiChangesetMut {
        author: "Test User <testuser@fb.com>".to_string(),
        message: message.to_string(),
        hg_extra,
        file_changes,
        ..Default::default()
    }
    .freeze()
    .expect("test changeset must be valid")
}

fn make_changeset_with_extras_and_files(
    extras: Vec<(&str, &[u8])>,
    files: Vec<&str>,
) -> BonsaiChangeset {
    make_changeset(extras, files, "message")
}

// =========================================================================
// Unit tests: RateLimit validation
// =========================================================================

#[mononoke::test]
fn test_rate_limit_valid_window() {
    assert!(RateLimit::new(3600, 10).is_ok());
}

#[mononoke::test]
fn test_rate_limit_max_window() {
    assert!(RateLimit::new(6 * 60 * 60, 10).is_ok());
}

#[mononoke::test]
fn test_rate_limit_window_too_large() {
    let result = RateLimit::new(7 * 60 * 60, 10);
    assert!(result.is_err());
    let err_msg = result.expect_err("expected error").to_string();
    assert!(
        err_msg.contains("exceeds maximum"),
        "Expected 'exceeds maximum' in error: {}",
        err_msg
    );
}

#[mononoke::test]
fn test_rate_limit_zero_window_rejected() {
    assert!(RateLimit::new(0, 10).is_err());
}

#[mononoke::test]
fn test_rate_limit_zero_max_commits_rejected() {
    assert!(RateLimit::new(3600, 0).is_err());
}

// =========================================================================
// Unit tests: CommitMessageTag eligibility
// =========================================================================

#[mononoke::test]
fn test_commit_message_tag_eligible() {
    let cs = make_changeset(vec![], vec!["a.txt"], "fix: apply AUTO_APPROVED changes");
    let check = EligibilityCheck::CommitMessageTag {
        tag: "AUTO_APPROVED".to_string(),
    };
    assert!(check.is_eligible(&cs));
}

#[mononoke::test]
fn test_commit_message_tag_not_present() {
    let cs = make_changeset(vec![], vec!["a.txt"], "regular commit message");
    let check = EligibilityCheck::CommitMessageTag {
        tag: "AUTO_APPROVED".to_string(),
    };
    assert!(!check.is_eligible(&cs));
}

#[mononoke::test]
fn test_commit_message_tag_case_sensitive() {
    let cs = make_changeset(vec![], vec!["a.txt"], "auto_approved lowercase");
    let check = EligibilityCheck::CommitMessageTag {
        tag: "AUTO_APPROVED".to_string(),
    };
    assert!(!check.is_eligible(&cs));
}

#[mononoke::test]
fn test_commit_message_tag_partial_match() {
    let cs = make_changeset(vec![], vec!["a.txt"], "this is AUTO_APPROVED_V2 stuff");
    let check = EligibilityCheck::CommitMessageTag {
        tag: "AUTO_APPROVED".to_string(),
    };
    // Substring match -- "AUTO_APPROVED" is contained in "AUTO_APPROVED_V2"
    assert!(check.is_eligible(&cs));
}

#[mononoke::test]
fn test_commit_message_tag_empty_message() {
    let cs = make_changeset(vec![], vec!["a.txt"], "");
    let check = EligibilityCheck::CommitMessageTag {
        tag: "AUTO_APPROVED".to_string(),
    };
    assert!(!check.is_eligible(&cs));
}

// =========================================================================
// Unit tests: HgExtra eligibility
// =========================================================================

#[mononoke::test]
fn test_hg_extra_eligible() {
    let cs = make_changeset_with_extras_and_files(vec![("auto_approved", b"1")], vec!["a.txt"]);
    let check = EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    };
    assert!(check.is_eligible(&cs));
}

#[mononoke::test]
fn test_hg_extra_not_present() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["a.txt"]);
    let check = EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    };
    assert!(!check.is_eligible(&cs));
}

#[mononoke::test]
fn test_hg_extra_wrong_key() {
    let cs = make_changeset_with_extras_and_files(vec![("other_key", b"1")], vec!["a.txt"]);
    let check = EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    };
    assert!(!check.is_eligible(&cs));
}

// =========================================================================
// Unit tests: OR semantics across eligibility checks
// =========================================================================

#[mononoke::test]
fn test_or_semantics_message_tag_matches() {
    let cs = make_changeset(vec![], vec!["a.txt"], "commit AUTO_APPROVED");
    let checks = vec![
        EligibilityCheck::CommitMessageTag {
            tag: "AUTO_APPROVED".to_string(),
        },
        EligibilityCheck::HgExtra {
            key: "auto_approved".to_string(),
        },
    ];
    assert!(is_eligible_for_rate_limit(&checks, &cs));
}

#[mononoke::test]
fn test_or_semantics_hg_extra_matches() {
    let cs = make_changeset_with_extras_and_files(vec![("auto_approved", b"1")], vec!["a.txt"]);
    let checks = vec![
        EligibilityCheck::CommitMessageTag {
            tag: "AUTO_APPROVED".to_string(),
        },
        EligibilityCheck::HgExtra {
            key: "auto_approved".to_string(),
        },
    ];
    assert!(is_eligible_for_rate_limit(&checks, &cs));
}

#[mononoke::test]
fn test_or_semantics_neither_matches() {
    let cs = make_changeset(vec![], vec!["a.txt"], "plain commit");
    let checks = vec![
        EligibilityCheck::CommitMessageTag {
            tag: "AUTO_APPROVED".to_string(),
        },
        EligibilityCheck::HgExtra {
            key: "auto_approved".to_string(),
        },
    ];
    assert!(!is_eligible_for_rate_limit(&checks, &cs));
}

// =========================================================================
// Unit tests: Directory filter
// =========================================================================

#[mononoke::test]
fn test_touches_directories_match() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["users/alice/foo.txt"]);
    let dirs = vec!["users/".to_string()];
    assert!(touches_directories(&cs, &dirs));
}

#[mononoke::test]
fn test_touches_directories_no_match() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["fbcode/bar.txt"]);
    let dirs = vec!["users/".to_string()];
    assert!(!touches_directories(&cs, &dirs));
}

#[mononoke::test]
fn test_empty_directories_always_matches() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["anything/file.txt"]);
    let dirs: Vec<String> = vec![];
    assert!(touches_directories(&cs, &dirs));
}

#[mononoke::test]
fn test_touches_directories_multiple_prefixes() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["configs/settings.json"]);
    let dirs = vec!["users/".to_string(), "configs/".to_string()];
    assert!(touches_directories(&cs, &dirs));
}

// =========================================================================
// Unit tests: Predicate
// =========================================================================

#[mononoke::test]
fn test_build_ancestor_predicate_eligible_and_touches() {
    let cs = make_changeset(
        vec![("auto_approved", b"1")],
        vec!["users/alice/foo.txt"],
        "msg",
    );
    let checks = vec![EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    }];
    let dirs = vec!["users/".to_string()];
    let predicate = build_ancestor_predicate(&checks, &dirs, None);
    assert!(predicate(&cs));
}

#[mononoke::test]
fn test_build_ancestor_predicate_not_eligible() {
    let cs = make_changeset_with_extras_and_files(vec![], vec!["users/alice/foo.txt"]);
    let checks = vec![EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    }];
    let dirs = vec!["users/".to_string()];
    let predicate = build_ancestor_predicate(&checks, &dirs, None);
    assert!(!predicate(&cs));
}

#[mononoke::test]
fn test_build_ancestor_predicate_wrong_directory() {
    let cs = make_changeset(vec![("auto_approved", b"1")], vec!["other.txt"], "msg");
    let checks = vec![EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    }];
    let dirs = vec!["users/".to_string()];
    let predicate = build_ancestor_predicate(&checks, &dirs, None);
    assert!(!predicate(&cs));
}

#[mononoke::test]
fn test_build_ancestor_predicate_user_filter_match() {
    let cs = make_changeset(
        vec![("auto_approved", b"1")],
        vec!["users/alice/foo.txt"],
        "msg",
    );
    let checks = vec![EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    }];
    let dirs = vec!["users/".to_string()];
    let predicate = build_ancestor_predicate(&checks, &dirs, Some("testuser"));
    assert!(predicate(&cs));
}

#[mononoke::test]
fn test_build_ancestor_predicate_user_filter_no_match() {
    let cs = make_changeset(
        vec![("auto_approved", b"1")],
        vec!["users/alice/foo.txt"],
        "msg",
    );
    let checks = vec![EligibilityCheck::HgExtra {
        key: "auto_approved".to_string(),
    }];
    let dirs = vec!["users/".to_string()];
    let predicate = build_ancestor_predicate(&checks, &dirs, Some("otheruser"));
    assert!(!predicate(&cs));
}

// =========================================================================
// Integration tests
//
// These exercise the complete check_commit_rate_limit() path with real
// commits in a test repo. They verify the restriction hierarchy of 4
// config instances:
//
//   (1) Global:          all dirs, all users, max=10
//   (2) Per-user:        all dirs, per user,  max=6
//   (3) users/ global:   users/ dir, all users, max=5
//   (4) users/ per-user: users/ dir, per user,  max=4
//
// Restriction increases (1)->(4): users/ per-user is most restrictive.
// =========================================================================

/// Create the shared test DAG with eligible ancestors.
///
/// Public history (bookmark "main" points at `tip`):
///   R -> A(eligible,users/,alice) -> B(eligible,users/,alice)
///     -> C(eligible,fbcode/,bob) -> D(eligible,users/,bob)
///     -> E(eligible,users/,alice) -> F(eligible,fbcode/,alice)
///     -> G(eligible,users/,alice) -> tip(not eligible, users/, alice)
///
/// Eligible ancestor counts from `tip`:
///   All eligible:          A,B,C,D,E,F,G = 7
///   users/ eligible:       A,B,D,E,G     = 5
///   alice all eligible:    A,B,E,F,G     = 5
///   alice users/ eligible: A,B,E,G       = 4
async fn setup_test_repo(
    fb: FacebookInit,
) -> Result<(CoreContext, TestRepo, BookmarkKey, ChangesetId)> {
    let ctx = CoreContext::test_mock(fb);
    let repo: TestRepo = test_repo_factory::build_empty(ctx.fb).await?;

    let root = CreateCommitContext::new_root(&ctx, &repo)
        .add_file("README", "init")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let a = CreateCommitContext::new(&ctx, &repo, vec![root])
        .add_file("users/alice/a.txt", "a")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let b = CreateCommitContext::new(&ctx, &repo, vec![a])
        .add_file("users/alice/b.txt", "b")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let c = CreateCommitContext::new(&ctx, &repo, vec![b])
        .add_file("fbcode/server/c.txt", "c")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(BOB)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let d = CreateCommitContext::new(&ctx, &repo, vec![c])
        .add_file("users/bob/d.txt", "d")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(BOB)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let e = CreateCommitContext::new(&ctx, &repo, vec![d])
        .add_file("users/alice/e.txt", "e")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let f = CreateCommitContext::new(&ctx, &repo, vec![e])
        .add_file("fbcode/server/f.txt", "f")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let g = CreateCommitContext::new(&ctx, &repo, vec![f])
        .add_file("users/alice/g.txt", "g")
        .add_extra(ELIGIBLE_EXTRA, b"1")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let tip = CreateCommitContext::new(&ctx, &repo, vec![g])
        .add_file("users/alice/tip.txt", "tip")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let bm = bookmark(&ctx, &repo, "main").create_publishing(tip).await?;

    Ok((ctx, repo, bm, tip))
}

/// Non-eligible commit is NEVER blocked, even when at the limit.
/// This is the most critical safety property.
#[mononoke::fbinit_test]
async fn test_non_eligible_commit_never_blocked(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 10);
    let per_user = make_config(&[], true, 6);
    let users_global = make_config(&["users/"], false, 5);
    let users_per_user = make_config(&["users/"], true, 4);

    let draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("users/alice/draft.txt", "draft")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs = draft.load(ctx, repo.repo_blobstore()).await?;

    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    Ok(())
}

/// Eligible commit under all limits: all configs accept.
#[mononoke::fbinit_test]
async fn test_under_all_limits_accepted(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 100);
    let per_user = make_config(&[], true, 100);
    let users_global = make_config(&["users/"], false, 100);
    let users_per_user = make_config(&["users/"], true, 100);

    // Use commit message tag for eligibility (primary production path)
    let draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("users/alice/draft.txt", "draft")
        .set_message(format!("eligible commit {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs = draft.load(ctx, repo.repo_blobstore()).await?;

    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    Ok(())
}

/// Restriction hierarchy: the most restrictive configs (users/ scoped)
/// fail first while less restrictive configs still accept.
#[mononoke::fbinit_test]
async fn test_most_restrictive_hook_fails_first(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 10);
    let per_user = make_config(&[], true, 6);
    let users_global = make_config(&["users/"], false, 5);
    let users_per_user = make_config(&["users/"], true, 4);

    let draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("users/alice/draft.txt", "draft")
        .set_message(format!("eligible commit {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs = draft.load(ctx, repo.repo_blobstore()).await?;

    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_global, None).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    Ok(())
}

/// Large draft stack exceeding all limits: all configs reject.
#[mononoke::fbinit_test]
async fn test_large_stack_all_hooks_reject(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 10);
    let per_user = make_config(&[], true, 6);
    let users_global = make_config(&["users/"], false, 5);
    let users_per_user = make_config(&["users/"], true, 4);

    let mut parent = tip;
    let mut last_cs_id = None;
    for i in 0..5 {
        let cs = CreateCommitContext::new(ctx, repo, vec![parent])
            .add_file(format!("users/alice/stack_{}.txt", i).as_str(), "x")
            .set_message(format!("stack commit {} {}", i, ELIGIBLE_TAG))
            .set_author(ALICE)
            .commit()
            .await?;
        parent = cs;
        last_cs_id = Some(cs);
    }
    let last = last_cs_id.expect("at least one commit created");
    let bcs = last.load(ctx, repo.repo_blobstore()).await?;

    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &per_user, Some("alice")).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_global, None).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Exceeded { .. },
    ));
    Ok(())
}

/// Eligible commit outside users/: directory-scoped configs skip it.
#[mononoke::fbinit_test]
async fn test_eligible_commit_outside_scoped_directory(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 10);
    let per_user = make_config(&[], true, 6);
    let users_global = make_config(&["users/"], false, 5);
    let users_per_user = make_config(&["users/"], true, 4);

    let draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("fbcode/server/new.txt", "new")
        .set_message(format!("eligible commit {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs = draft.load(ctx, repo.repo_blobstore()).await?;

    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    Ok(())
}

/// Per-user configs only count the commit's author. bob passes where alice fails.
#[mononoke::fbinit_test]
async fn test_different_user_not_blocked_by_per_user_limit(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let strict_per_user = make_config(&[], true, 3);

    let alice_draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("fbcode/alice_new.txt", "x")
        .set_message(format!("alice commit {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let alice_bcs = alice_draft.load(ctx, repo.repo_blobstore()).await?;
    assert!(matches!(
        check_commit_rate_limit(ctx, repo, &bm, &alice_bcs, &strict_per_user, Some("alice"))
            .await?,
        RateLimitOutcome::Exceeded { .. },
    ));

    let bob_draft = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("fbcode/bob_new.txt", "x")
        .set_message(format!("bob commit {}", ELIGIBLE_TAG))
        .set_author(BOB)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bob_bcs = bob_draft.load(ctx, repo.repo_blobstore()).await?;
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bob_bcs, &strict_per_user, Some("bob")).await?,
        RateLimitOutcome::Allowed,
    );
    Ok(())
}

/// New bookmark with no history: always accept.
#[mononoke::fbinit_test]
async fn test_new_bookmark_no_ancestors(fb: FacebookInit) -> Result<()> {
    let ctx = CoreContext::test_mock(fb);
    let repo: TestRepo = test_repo_factory::build_empty(ctx.fb).await?;
    borrowed!(ctx, repo);

    let global = make_config(&[], false, 10);
    let users_per_user = make_config(&["users/"], true, 4);
    let bm = BookmarkKey::new("new_branch")?;

    let root = CreateCommitContext::new_root(ctx, repo)
        .add_file("users/alice/first.txt", "first")
        .set_message(format!("first commit {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs = root.load(ctx, repo.repo_blobstore()).await?;

    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &global, None).await?,
        RateLimitOutcome::Allowed,
    );
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
    );
    Ok(())
}

/// Draft stack bypass prevention: draft ancestors are counted so a user
/// can't bypass limits by batching commits into one push. Also verifies
/// that a non-eligible commit on top of a rejected stack still passes.
#[mononoke::fbinit_test]
async fn test_draft_stack_bypass_prevention(fb: FacebookInit) -> Result<()> {
    let (ctx, repo, bm, tip) = setup_test_repo(fb).await?;
    borrowed!(ctx, repo);

    let users_per_user = make_config(&["users/"], true, 4);

    let draft_1 = CreateCommitContext::new(ctx, repo, vec![tip])
        .add_file("users/alice/stack_1.txt", "1")
        .set_message(format!("stack 1 {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let draft_2 = CreateCommitContext::new(ctx, repo, vec![draft_1])
        .add_file("users/alice/stack_2.txt", "2")
        .set_message(format!("stack 2 {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let draft_3 = CreateCommitContext::new(ctx, repo, vec![draft_2])
        .add_file("users/alice/stack_3.txt", "3")
        .set_message(format!("stack 3 {}", ELIGIBLE_TAG))
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;

    let bcs_1 = draft_1.load(ctx, repo.repo_blobstore()).await?;
    assert!(
        matches!(
            check_commit_rate_limit(ctx, repo, &bm, &bcs_1, &users_per_user, Some("alice")).await?,
            RateLimitOutcome::Exceeded { .. },
        ),
        "draft_1: alice already at limit from public ancestors"
    );

    let bcs_3 = draft_3.load(ctx, repo.repo_blobstore()).await?;
    assert!(
        matches!(
            check_commit_rate_limit(ctx, repo, &bm, &bcs_3, &users_per_user, Some("alice")).await?,
            RateLimitOutcome::Exceeded { .. },
        ),
        "draft_3: 4 public + 2 draft ancestors"
    );

    // Non-eligible commit on top of rejected stack -> ACCEPT
    let non_eligible = CreateCommitContext::new(ctx, repo, vec![draft_3])
        .add_file("users/alice/safe.txt", "safe")
        .set_author(ALICE)
        .set_author_date(recent_date())
        .commit()
        .await?;
    let bcs_safe = non_eligible.load(ctx, repo.repo_blobstore()).await?;
    assert_eq!(
        check_commit_rate_limit(ctx, repo, &bm, &bcs_safe, &users_per_user, Some("alice")).await?,
        RateLimitOutcome::Allowed,
        "non-eligible commit must always pass",
    );
    Ok(())
}
