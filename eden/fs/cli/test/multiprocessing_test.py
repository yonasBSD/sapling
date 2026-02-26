#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2.

# pyre-strict

import errno
import tempfile
import unittest

from .. import mtab


class MultiprocessingTest(unittest.TestCase):
    def test_create_lstat_process_completes_successfully(self) -> None:
        table = mtab.new()
        proc = table.create_lstat_process(tempfile.gettempdir().encode())
        proc.start()
        proc.join(timeout=0.5)

        self.assertFalse(proc.is_alive())
        self.assertEqual(proc.exitcode, errno.ENOENT)
