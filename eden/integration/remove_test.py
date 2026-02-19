#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-unsafe

import os
import time
from typing import Set

from parameterized import parameterized

from .lib import testcase


class RemoveTestBase(testcase.EdenRepoTest):
    """Base class for Eden remove command tests."""

    # pyre-fixme[13]: Attribute `expected_mount_entries` is never initialized.
    expected_mount_entries: Set[str]

    def setup_eden_test(self) -> None:
        self.enable_windows_symlinks = True
        super().setup_eden_test()

    def populate_repo(self) -> None:
        self.repo.write_file("hello", "hola\n")
        self.repo.write_file("adir/file", "foo!\n")
        self.repo.write_file("bdir/test.sh", "#!/bin/bash\necho test\n", mode=0o755)
        self.repo.write_file("bdir/noexec.sh", "#!/bin/bash\necho test\n")
        self.repo.symlink("slink", os.path.join("adir", "file"))

        self.repo.commit("Initial commit.")

        self.expected_mount_entries = {".eden", "adir", "bdir", "hello", "slink"}
        if self.repo.get_type() in ["hg", "filteredhg"]:
            self.expected_mount_entries.add(".hg")


@testcase.eden_repo_test
class RemoveTest(RemoveTestBase):
    """Tests for the eden remove command.

    These tests exercise various remove scenarios including redirections,
    timeouts, and handling of busy mounts.
    """

    @parameterized.expand(
        [
            ("rust", {"EDENFSCTL_ONLY_RUST": "1"}),
            ("python", {"EDENFSCTL_SKIP_RUST": "1"}),
        ]
    )
    def test_remove_aux_process_timeout(self, impl: str, env: dict) -> None:
        """Test that eden rm correctly handles aux process timeout.

        Uses two mounts with an injected 2-second delay and a 1s timeout
        to verify that:
        1. Each mount gets its own full timeout
        2. The timeout message includes the step name to help identify what was stuck
        3. Both mounts are removed despite the timeouts
        """
        # Create a second mount
        mount2 = os.path.join(self.tmp_dir, "mount2")
        self.eden.clone(self.repo.path, mount2)

        full_env = {
            **env,
            # Inject a 2-second delay to simulate slow aux process stopping
            "EDENFS_AUX_PROCESSES_TEST_DELAY_SECS": "2",
        }

        start_time = time.time()
        result = self.eden.run_unchecked(
            "remove",
            "--yes",
            "--timeout",
            "1",
            self.mount,
            mount2,
            env=full_env,
            capture_output=True,
            text=True,
        )
        elapsed_time = time.time() - start_time

        # With per-mount timeout, each mount gets 1s timeout independently.
        # Total time: 2 mounts × 1s timeout + overhead = ~2-3s
        self.assertGreater(
            elapsed_time,
            2.0,
            f"eden rm ({impl}) should use per-mount timeout (expected >2s, got {elapsed_time:.1f}s)",
        )
        self.assertLess(
            elapsed_time,
            3.0,
            f"eden rm ({impl}) should not wait for the full delay (expected <3s, got {elapsed_time:.1f}s)",
        )

        output = result.stderr or ""

        # Verify the timeout message includes step information
        self.assertIn(
            "timed out",
            output.lower(),
            f"eden rm ({impl}) should log timeout message. Output: {output}",
        )
        # Check that the output includes the step name.
        # Python uses a step tracker that starts at "initializing" (the delay is injected
        # before the step is updated), while Rust reports "unmounting redirections" directly.
        if impl == "python":
            expected_step = "initializing"
        else:
            expected_step = "unmounting redirections"
        self.assertIn(
            expected_step,
            output.lower(),
            f"eden rm ({impl}) should log the step name that timed out. Output: {output}",
        )

        # Verify both mounts were removed despite the timeouts
        self.assertFalse(
            os.path.exists(self.mount),
            "first mount point should be removed",
        )
        self.assertFalse(
            os.path.exists(mount2),
            "second mount point should be removed",
        )
