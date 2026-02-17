/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

CREATE TABLE IF NOT EXISTS `long_running_request_dependencies` (
  `request_id` INTEGER NOT NULL,
  `depends_on_request_id` INTEGER NOT NULL,
  PRIMARY KEY (`request_id`, `depends_on_request_id`)
);

CREATE INDEX IF NOT EXISTS `idx_depends_on`
  ON `long_running_request_dependencies` (`depends_on_request_id`);
