/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

CREATE TABLE IF NOT EXISTS `commit_derived_data` (
    `repo_id` INT(11) NOT NULL,
    `cs_id` VARBINARY(32) NOT NULL,
    `derived_data_type` INT(11) NOT NULL,
    `derived_data_version` INT(11) NOT NULL,
    `derived_value` VARBINARY(32) NOT NULL,
    PRIMARY KEY (`repo_id`, `cs_id`, `derived_data_type`, `derived_data_version`)
);
