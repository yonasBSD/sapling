/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {CommandArg} from '../types';

import {Operation} from './Operation';

export class RenameWorktreeOperation extends Operation {
  static opName = 'RenameWorktree';

  constructor(
    private worktreePath: string,
    private newLabel: string | undefined,
  ) {
    super('RenameWorktreeOperation');
  }

  getArgs(): Array<CommandArg> {
    if (this.newLabel == null || this.newLabel === '') {
      // Remove the label
      return ['worktree', 'label', this.worktreePath, '--remove'];
    }
    return ['worktree', 'label', this.worktreePath, this.newLabel];
  }
}
