/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {WorktreeInfo} from '../types';

import {act, render, screen, within} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import App from '../App';
import platform from '../platform';
import {mostRecentSubscriptionIds} from '../serverAPIState';
import {
  closeCommitInfoSidebar,
  COMMIT,
  expectMessageSentToServer,
  resetTestMessages,
  simulateCommits,
  simulateMessageFromServer,
  simulateRepoConnected,
} from '../testUtils';

function simulateWorktreeInfo(worktreeInfo: WorktreeInfo | undefined) {
  simulateMessageFromServer({
    type: 'subscriptionResult',
    kind: 'worktreeInfo',
    subscriptionID: mostRecentSubscriptionIds.worktreeInfo,
    data: worktreeInfo,
  });
}

describe('worktree support in CwdSelector', () => {
  const worktreeInfo: WorktreeInfo = {
    sharedRoot: '/repo/main',
    worktrees: [
      {path: '/repo/main', role: 'main'},
      {path: '/repo/feature-x', label: 'feature-x', role: 'linked'},
      {path: '/repo/bugfix', label: 'bugfix-123', role: 'linked'},
    ],
  };

  beforeEach(() => {
    render(<App />);
    act(() => {
      closeCommitInfoSidebar();
      expectMessageSentToServer({
        type: 'subscribe',
        kind: 'smartlogCommits',
        subscriptionID: expect.anything(),
      });
    });
  });

  it('connects successfully when worktreeInfo is present', () => {
    act(() => {
      simulateRepoConnected('/repo/main');
      simulateWorktreeInfo(worktreeInfo);
      simulateCommits({
        value: [
          COMMIT('1', 'some public base', '0', {phase: 'public'}),
          COMMIT('a', 'My Commit', '1', {isDot: true}),
        ],
      });
    });

    // The app should render normally with worktreeInfo present
    expect(screen.getByText('My Commit')).toBeInTheDocument();
  });

  it('connects successfully when worktreeInfo is undefined (solo repo)', () => {
    act(() => {
      simulateRepoConnected('/path/to/repo');
      simulateCommits({
        value: [
          COMMIT('1', 'some public base', '0', {phase: 'public'}),
          COMMIT('a', 'My Commit', '1', {isDot: true}),
        ],
      });
    });

    // The app should render normally without worktreeInfo
    expect(screen.getByText('My Commit')).toBeInTheDocument();
  });

  it('switching worktrees sends changeCwd with the worktree path', () => {
    act(() => {
      simulateRepoConnected('/repo/main');
      simulateWorktreeInfo(worktreeInfo);
      simulateCommits({
        value: [
          COMMIT('1', 'some public base', '0', {phase: 'public'}),
          COMMIT('a', 'My Commit', '1', {isDot: true}),
        ],
      });
    });

    // Simulate a worktree switch by triggering changeActiveRepo from server
    resetTestMessages();
    act(() => {
      simulateMessageFromServer({
        type: 'changeActiveRepo',
        cwd: '/repo/feature-x',
      });
    });

    expectMessageSentToServer({type: 'changeCwd', cwd: '/repo/feature-x'});
  });

  it('worktreeInfo is not present for worktree in non-worktree repo', () => {
    act(() => {
      simulateRepoConnected('/repo/main');
      simulateCommits({
        value: [
          COMMIT('1', 'some public base', '0', {phase: 'public'}),
          COMMIT('a', 'My Commit', '1', {isDot: true}),
        ],
      });
    });

    // App renders without issues when worktreeInfo is absent
    expect(screen.getByText('My Commit')).toBeInTheDocument();
  });

  it('worktreeInfo correctly identifies non-main worktree', () => {
    const featureWorktreeInfo: WorktreeInfo = {
      sharedRoot: '/repo/main',
      worktrees: [
        {path: '/repo/main', role: 'main'},
        {path: '/repo/feature-x', label: 'feature-x', role: 'linked'},
      ],
    };

    act(() => {
      simulateRepoConnected('/repo/feature-x');
      simulateWorktreeInfo(featureWorktreeInfo);
      simulateCommits({
        value: [
          COMMIT('1', 'some public base', '0', {phase: 'public'}),
          COMMIT('a', 'Feature Commit', '1', {isDot: true}),
        ],
      });
    });

    // The app should render from the feature worktree's perspective
    expect(screen.getByText('Feature Commit')).toBeInTheDocument();
  });

  describe('WorktreeSection UI', () => {
    async function openCwdDropdown() {
      const button = screen.getByTestId('cwd-dropdown-button');
      await userEvent.click(button);
    }

    it('renders WorktreeSection when worktreeInfo is present', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      expect(screen.getByTestId('worktree-section')).toBeInTheDocument();
    });

    it('renders WorktreeSection with only Add button when worktreeInfo is undefined', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      expect(screen.getByTestId('worktree-section')).toBeInTheDocument();
      expect(screen.getByTestId('add-worktree-button')).toBeInTheDocument();
      expect(screen.queryByTestId('current-worktree')).not.toBeInTheDocument();
      expect(screen.queryByTestId('sibling-worktree')).not.toBeInTheDocument();
    });

    it('shows current worktree highlighted', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      const currentWorktree = screen.getByTestId('current-worktree');
      expect(currentWorktree).toBeInTheDocument();
      expect(within(currentWorktree).getByText('main', {selector: 'code'})).toBeInTheDocument();
    });

    it('shows sibling worktrees sorted alphabetically', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      const siblings = screen.getAllByTestId('sibling-worktree');
      expect(siblings).toHaveLength(2);
      expect(within(siblings[0]).getByText('bugfix', {selector: 'code'})).toBeInTheDocument();
      expect(within(siblings[1]).getByText('feature-x', {selector: 'code'})).toBeInTheDocument();
    });

    it('clicking Switch on a sibling worktree sends changeCwd when not in vscode', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      resetTestMessages();

      const switchButtons = screen.getAllByTestId('worktree-switch-button');
      await userEvent.click(switchButtons[0]);

      expectMessageSentToServer({type: 'changeCwd', cwd: '/repo/bugfix'});
    });

    it('clicking Switch on a sibling worktree opens confirm modal in vscode', async () => {
      const originalPlatformName = platform.platformName;
      Object.defineProperty(platform, 'platformName', {
        value: 'vscode',
        writable: true,
        configurable: true,
      });

      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      resetTestMessages();

      const switchButtons = screen.getAllByTestId('worktree-switch-button');
      await userEvent.click(switchButtons[0]);

      const openButton = await screen.findByText('Open in Current Window');
      await userEvent.click(openButton);

      expectMessageSentToServer({type: 'platform/openFolder', path: '/repo/bugfix'});

      Object.defineProperty(platform, 'platformName', {
        value: originalPlatformName,
        writable: true,
        configurable: true,
      });
    });

    it('clicking Remove on a sibling worktree sends runOperation', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();
      resetTestMessages();

      const removeButtons = screen.getAllByTestId('worktree-remove-button');
      await userEvent.click(removeButtons[0]);

      expectMessageSentToServer({
        type: 'runOperation',
        operation: expect.objectContaining({
          args: ['worktree', 'remove', '/repo/bugfix'],
        }),
      });
    });

    it('AddWorktreeForm opens modal with prepopulated path and form fields', async () => {
      act(() => {
        simulateRepoConnected('/repo/main');
        simulateWorktreeInfo(worktreeInfo);
        simulateCommits({
          value: [
            COMMIT('1', 'some public base', '0', {phase: 'public'}),
            COMMIT('a', 'My Commit', '1', {isDot: true}),
          ],
        });
      });

      await openCwdDropdown();

      const addButton = screen.getByTestId('add-worktree-button');
      await act(async () => {
        await userEvent.click(addButton);
      });

      const pathInput = await screen.findByTestId('add-worktree-path');
      expect(pathInput).toBeInTheDocument();
      expect((pathInput as HTMLInputElement).value).toContain('.worktrees');

      const labelInput = screen.getByTestId('add-worktree-label');
      expect(labelInput).toBeInTheDocument();

      const submitButton = screen.getByTestId('add-worktree-submit');
      expect(submitButton).toBeInTheDocument();
    });
  });
});
