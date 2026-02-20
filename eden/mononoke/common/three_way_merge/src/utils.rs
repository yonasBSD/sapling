/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! Utilities for 3-way merge: binary detection, line splitting, range comparison.

/// Returns `true` if the content is binary (contains a null byte).
pub fn is_binary(content: &[u8]) -> bool {
    content.contains(&0)
}

/// Split content into lines, preserving line endings.
///
/// Each line includes its trailing `\n` if present. The last line
/// may not have a trailing newline.
pub fn split_lines(content: &[u8]) -> Vec<&[u8]> {
    if content.is_empty() {
        return Vec::new();
    }
    let mut lines = Vec::new();
    let mut start = 0;
    for (i, &byte) in content.iter().enumerate() {
        if byte == b'\n' {
            lines.push(&content[start..=i]);
            start = i + 1;
        }
    }
    // Handle last line without trailing newline
    if start < content.len() {
        lines.push(&content[start..]);
    }
    lines
}

/// Compare two line slices for equality.
///
/// Returns `Ok(true)` if `a[a_range]` and `b[b_range]` contain the same lines,
/// `Ok(false)` if they differ, or `Err` if either range is out of bounds.
pub fn compare_range(
    a: &[&[u8]],
    a_range: std::ops::Range<usize>,
    b: &[&[u8]],
    b_range: std::ops::Range<usize>,
) -> Result<bool, String> {
    if a_range.end > a.len() {
        return Err(format!(
            "a_range {}..{} out of bounds for slice of length {}",
            a_range.start,
            a_range.end,
            a.len()
        ));
    }
    if b_range.end > b.len() {
        return Err(format!(
            "b_range {}..{} out of bounds for slice of length {}",
            b_range.start,
            b_range.end,
            b.len()
        ));
    }
    Ok(a[a_range] == b[b_range])
}

#[cfg(test)]
mod tests {
    use mononoke_macros::mononoke;

    use super::*;

    #[mononoke::test]
    fn test_is_binary_with_null() {
        assert!(is_binary(b"hello\0world"));
    }

    #[mononoke::test]
    fn test_is_binary_text() {
        assert!(!is_binary(b"hello world\n"));
    }

    #[mononoke::test]
    fn test_is_binary_empty() {
        assert!(!is_binary(b""));
    }

    #[mononoke::test]
    fn test_split_lines_basic() {
        let lines = split_lines(b"a\nb\nc\n");
        assert_eq!(lines, vec![b"a\n".as_slice(), b"b\n", b"c\n"]);
    }

    #[mononoke::test]
    fn test_split_lines_no_trailing_newline() {
        let lines = split_lines(b"a\nb\nc");
        assert_eq!(lines, vec![b"a\n".as_slice(), b"b\n", b"c"]);
    }

    #[mononoke::test]
    fn test_split_lines_empty() {
        let lines = split_lines(b"");
        assert!(lines.is_empty());
    }

    #[mononoke::test]
    fn test_split_lines_single_newline() {
        let lines = split_lines(b"\n");
        assert_eq!(lines, vec![b"\n".as_slice()]);
    }

    #[mononoke::test]
    fn test_compare_range_equal() {
        let a: Vec<&[u8]> = vec![b"x", b"y", b"z"];
        let b: Vec<&[u8]> = vec![b"x", b"y", b"z"];
        assert!(compare_range(&a, 0..3, &b, 0..3).unwrap());
    }

    #[mononoke::test]
    fn test_compare_range_subrange() {
        let a: Vec<&[u8]> = vec![b"a", b"x", b"y", b"b"];
        let b: Vec<&[u8]> = vec![b"x", b"y"];
        assert!(compare_range(&a, 1..3, &b, 0..2).unwrap());
    }

    #[mononoke::test]
    fn test_compare_range_different() {
        let a: Vec<&[u8]> = vec![b"x", b"y"];
        let b: Vec<&[u8]> = vec![b"x", b"z"];
        assert!(!compare_range(&a, 0..2, &b, 0..2).unwrap());
    }

    #[mononoke::test]
    fn test_compare_range_different_lengths() {
        let a: Vec<&[u8]> = vec![b"x", b"y"];
        let b: Vec<&[u8]> = vec![b"x"];
        assert!(!compare_range(&a, 0..2, &b, 0..1).unwrap());
    }

    #[mononoke::test]
    fn test_compare_range_out_of_bounds() {
        let a: Vec<&[u8]> = vec![b"x", b"y"];
        let b: Vec<&[u8]> = vec![b"x"];
        assert!(compare_range(&a, 0..5, &b, 0..1).is_err());
        assert!(compare_range(&a, 0..2, &b, 0..3).is_err());
    }
}
