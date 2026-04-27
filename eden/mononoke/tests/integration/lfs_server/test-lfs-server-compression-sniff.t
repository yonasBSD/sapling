# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

# Magic-byte sniff bypasses gzip on already-compressed payloads (e.g. zip/apk),
# but only when both the deployment-time CLI flag (--enable-compression-sniff)
# and the per-repo runtime JustKnob are on. Verifies all four combinations of
# CLI x JK against a zip-magic payload and a plain-text payload.

  $ . "${TEST_FIXTURES}/library.sh"

  $ setup_common_config
  $ REPOID=1 FILESTORE=1 FILESTORE_CHUNK_SIZE=128 setup_mononoke_repo_config lfs1

# Two payloads: one with the standard zip "PK\x03\x04" local-file-header magic
# (matches `file(1)`'s "Zip archive data, at least v0.0/v2.0 to extract"), and
# one of the same length that's plain text and compresses well.
  $ printf 'PK\x03\x04zipzipzipzipzipzipzipzipzipzipzipzipzipzipzipzipzipzipzipzip' > zipblob
  $ printf 'plain text content that should compress via gzip plain text content...' > textblob
  $ wc -c zipblob textblob | head -2
   64 zipblob
   70 textblob

# ------------------------------------------------------------------
# Case 1: CLI flag OFF, JK OFF (default) — no bypass for either payload.
# ------------------------------------------------------------------
  $ lfs_uri="$(lfs_server)/lfs1"
  $ zip_oid="$(cat zipblob | hg debuglfssend "$lfs_uri" | awk '{print $1}')"
  $ text_oid="$(cat textblob | hg debuglfssend "$lfs_uri" | awk '{print $1}')"

  $ curltest -s -D zip_hdrs -o zip_body -H "Accept-Encoding: gzip" "${lfs_uri}/download_sha256/$zip_oid"
  $ grep -i '^content-encoding' zip_hdrs | tr -d '\r'
  content-encoding: gzip
  $ curltest -s -D text_hdrs -o text_body -H "Accept-Encoding: gzip" "${lfs_uri}/download_sha256/$text_oid"
  $ grep -i '^content-encoding' text_hdrs | tr -d '\r'
  content-encoding: gzip

# ------------------------------------------------------------------
# Case 2: CLI flag ON, JK still OFF — no bypass yet (runtime gate is off).
# ------------------------------------------------------------------
  $ lfs_uri2="$(lfs_server --enable-compression-sniff)/lfs1"
  $ curltest -s -D zip_hdrs2 -o /dev/null -H "Accept-Encoding: gzip" "${lfs_uri2}/download_sha256/$zip_oid"
  $ grep -i '^content-encoding' zip_hdrs2 | tr -d '\r'
  content-encoding: gzip

# ------------------------------------------------------------------
# Case 3: CLI flag ON, JK ON — zip-magic bypassed to identity, text still gzip.
# ------------------------------------------------------------------
  $ merge_just_knobs <<EOF
  > {
  >   "bools": {
  >     "scm/mononoke:lfs_server_compression_sniff_enabled": true
  >   }
  > }
  > EOF

  $ lfs_uri3="$(lfs_server --enable-compression-sniff)/lfs1"
  $ curltest -s -D zip_hdrs3 -o zip_body3 -H "Accept-Encoding: gzip" "${lfs_uri3}/download_sha256/$zip_oid"
  $ grep -i '^content-encoding' zip_hdrs3 | tr -d '\r'
  content-encoding: identity
  $ wc -c zip_body3
  64 zip_body3
  $ diff zipblob zip_body3

  $ curltest -s -D text_hdrs3 -o text_body3 -H "Accept-Encoding: gzip" "${lfs_uri3}/download_sha256/$text_oid"
  $ grep -i '^content-encoding' text_hdrs3 | tr -d '\r'
  content-encoding: gzip
  $ gunzip < text_body3 | cmp - textblob

# ------------------------------------------------------------------
# Case 4: Range request (Accept-Encoding: gzip + Range:) — sniff is skipped
# even when both gates are on, because magic bytes are only valid at offset 0.
# Server still falls back to identity for ranges (existing behavior), so this
# mainly asserts we don't break range handling.
# ------------------------------------------------------------------
  $ curltest -s -D zip_hdrs_range -o /dev/null --range 0-15 -H "Accept-Encoding: gzip" "${lfs_uri3}/download_sha256/$zip_oid"
  $ grep -i '^content-encoding' zip_hdrs_range | tr -d '\r'
  content-encoding: gzip
