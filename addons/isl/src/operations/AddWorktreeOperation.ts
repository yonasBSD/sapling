/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {CommandArg} from '../types';

import {Operation} from './Operation';

export class AddWorktreeOperation extends Operation {
  static opName = 'AddWorktree';

  constructor(
    private destinationPath: string,
    private label?: string,
  ) {
    super('AddWorktreeOperation');
  }

  getArgs(): Array<CommandArg> {
    const args: Array<CommandArg> = ['worktree', 'add', this.destinationPath];
    if (this.label) {
      args.push('--label', this.label);
    }
    return args;
  }
}
