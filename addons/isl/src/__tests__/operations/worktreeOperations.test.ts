/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {AddWorktreeOperation} from '../../operations/AddWorktreeOperation';
import {RemoveWorktreeOperation} from '../../operations/RemoveWorktreeOperation';

describe('AddWorktreeOperation', () => {
  it('produces correct args with just a path', () => {
    const op = new AddWorktreeOperation('/home/user/feature-x');
    expect(op.getArgs()).toEqual(['worktree', 'add', '/home/user/feature-x']);
  });

  it('produces correct args with a label', () => {
    const op = new AddWorktreeOperation('/home/user/feature-x', 'feature-x');
    expect(op.getArgs()).toEqual([
      'worktree',
      'add',
      '/home/user/feature-x',
      '--label',
      'feature-x',
    ]);
  });

  it('has the correct track event name', () => {
    const op = new AddWorktreeOperation('/path');
    expect(op.trackEventName).toBe('AddWorktreeOperation');
  });

  it('serializes to a runnable operation', () => {
    const op = new AddWorktreeOperation('/home/user/feature-x', 'feature-x');
    const runnable = op.getRunnableOperation();
    expect(runnable.args).toEqual(op.getArgs());
    expect(runnable.id).toBe(op.id);
    expect(runnable.trackEventName).toBe('AddWorktreeOperation');
  });
});

describe('RemoveWorktreeOperation', () => {
  it('produces correct args', () => {
    const op = new RemoveWorktreeOperation('/home/user/feature-x');
    expect(op.getArgs()).toEqual(['worktree', 'remove', '/home/user/feature-x']);
  });

  it('has the correct track event name', () => {
    const op = new RemoveWorktreeOperation('/path');
    expect(op.trackEventName).toBe('RemoveWorktreeOperation');
  });

  it('serializes to a runnable operation', () => {
    const op = new RemoveWorktreeOperation('/home/user/feature-x');
    const runnable = op.getRunnableOperation();
    expect(runnable.args).toEqual(op.getArgs());
    expect(runnable.id).toBe(op.id);
    expect(runnable.trackEventName).toBe('RemoveWorktreeOperation');
  });
});
