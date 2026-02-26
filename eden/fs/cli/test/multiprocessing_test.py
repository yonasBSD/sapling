#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-strict

import tempfile
import unittest

from .. import mtab


class MultiprocessingTest(unittest.TestCase):
    def test_create_lstat_process_completes_successfully(self) -> None:
        table = mtab.new()
        proc = table.create_lstat_process(tempfile.gettempdir().encode())
        proc.start()
        proc.join(timeout=0.5)

        # We only care that the child process did not hit a runtime exception
        # (e.g. ImportError loading thrift). Python exits with code 1 for
        # unhandled exceptions. The child may still be running if the join
        # timed out (exitcode is None), or exit with 0/errno — all fine.
        if proc.exitcode is not None:
            self.assertNotEqual(proc.exitcode, 1)
