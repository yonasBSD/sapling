/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::io::Write;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::bail;
use clidispatch::ReqCtx;
use clidispatch::fallback;
use cmdutil::ConfigExt;
use cmdutil::Result;
use cmdutil::WalkOpts;
use cmdutil::define_flags;
use filewalk::walk_and_fetch;
use grep::regex::RegexMatcher;
use grep::searcher::Searcher;
use grep::searcher::sinks::Lossy;
use pathmatcher::DynMatcher;
use pathmatcher::IntersectMatcher;
use repo::CoreRepo;

define_flags! {
    pub struct GrepOpts {
        walk_opts: WalkOpts,

        /// print NUM lines of trailing context
        #[short('A')]
        #[argtype("NUM")]
        after_context: Option<i64>,

        /// print NUM lines of leading context
        #[short('B')]
        #[argtype("NUM")]
        before_context: Option<i64>,

        /// print NUM lines of output context
        #[short('C')]
        #[argtype("NUM")]
        context: Option<i64>,

        /// ignore case when matching
        #[short('i')]
        ignore_case: bool,

        /// print only filenames that match
        #[short('l')]
        files_with_matches: bool,

        /// print matching line numbers
        #[short('n')]
        line_number: bool,

        /// select non-matching lines
        #[short('V')]
        invert_match: bool,

        /// match whole words only
        #[short('w')]
        word_regexp: bool,

        /// use POSIX extended regexps
        #[short('E')]
        extended_regexp: bool,

        /// interpret pattern as fixed string
        #[short('F')]
        fixed_strings: bool,

        /// use Perl-compatible regexps
        #[short('P')]
        perl_regexp: bool,

        #[arg]
        grep_pattern: String,

        #[args]
        sl_patterns: Vec<String>,
    }
}

pub fn run(ctx: ReqCtx<GrepOpts>, repo: &CoreRepo) -> Result<u8> {
    if !repo.config().get_or("grep", "use-rust", || false)? {
        fallback!("grep.use-rust");
    }

    let pattern = &ctx.opts.grep_pattern;
    let regex_matcher = match RegexMatcher::new(pattern) {
        Ok(m) => m,
        Err(e) => bail!("invalid grep pattern '{}': {:?}", pattern, e),
    };

    let (repo_root, case_sensitive, cwd) = match repo {
        CoreRepo::Disk(repo) => {
            let wc = repo.working_copy()?;
            let wc = wc.read();
            let vfs = wc.vfs();
            (
                vfs.root().to_path_buf(),
                vfs.case_sensitive(),
                std::env::current_dir()?,
            )
        }
        CoreRepo::Slapi(_slapi_repo) => (PathBuf::new(), true, PathBuf::new()),
    };

    let matcher = pathmatcher::cli_matcher(
        &ctx.opts.sl_patterns,
        &ctx.opts.walk_opts.include,
        &ctx.opts.walk_opts.exclude,
        pathmatcher::PatternKind::RelPath,
        case_sensitive,
        &repo_root,
        &cwd,
        &mut ctx.io().input(),
    )?;

    let mut matcher: DynMatcher = Arc::new(matcher);

    let tree_resolver = repo.tree_resolver()?;
    // TODO - other support other revs.
    let manifest = tree_resolver.get(&repo.resolve_commit(".")?)?;
    let file_store = repo.file_store()?;

    // Check for sparse profile and intersect with existing matcher if set.
    if let Some(sparse_matcher) = repo.sparse_matcher(&manifest)? {
        matcher = Arc::new(IntersectMatcher::new(vec![matcher, sparse_matcher]));
    }

    ctx.maybe_start_pager(repo.config())?;

    let (file_rx, first_error) = walk_and_fetch(&manifest, matcher, &file_store);

    let mut match_count = 0;
    let mut searcher = Searcher::new();
    let io = ctx.io();

    for file_result in file_rx {
        if first_error.has_error() {
            break;
        }

        let path = file_result.path.as_str();

        let _ = file_result.data.each_chunk(|chunk| {
            // Search the file contents
            let result = searcher.search_slice(
                &regex_matcher,
                chunk,
                Lossy(|_line_num, line| {
                    match_count += 1;
                    let mut out = io.output();
                    write!(out, "{}:{}", path, line)?;
                    Ok(true)
                }),
            );

            if let Err(e) = result {
                first_error.send_error(e.into());
                Err(std::io::Error::other("break"))
            } else {
                Ok(())
            }
        });
    }

    first_error.wait()?;

    Ok(if match_count > 0 { 0 } else { 1 })
}

pub fn aliases() -> &'static str {
    "grep|gre"
}

pub fn doc() -> &'static str {
    r#"search for a pattern in tracked files in the working directory

    The default regexp style is POSIX basic regexps. If no FILE parameters are
    passed in, the current directory and its subdirectories will be searched.

    For the old '@prog@ grep', which searches through history, see 'histgrep'."#
}

pub fn synopsis() -> Option<&'static str> {
    Some("[OPTION]... PATTERN [FILE]...")
}
