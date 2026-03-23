/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {Comparison} from 'shared/Comparison';
import type {RepoRelativePath} from '../types';

import {atom} from 'jotai';
import {ComparisonType} from 'shared/Comparison';
import {writeAtom} from '../jotaiUtils';
import platform from '../platform';

export type ComparisonMode = {
  comparison: Comparison;
  visible: boolean;
  /** When set, only show the diff for this specific file. */
  focusedFile?: RepoRelativePath;
};
export const currentComparisonMode = atom<ComparisonMode>(
  window.islAppMode?.mode === 'comparison'
    ? {
        comparison: window.islAppMode.comparison,
        visible: true,
      }
    : {
        comparison: {type: ComparisonType.UncommittedChanges},
        visible: false,
      },
);

/** Open Comparison View, optionally focused on a single file */
export async function showComparison(comparison: Comparison, focusedFile?: RepoRelativePath) {
  if (await platform.openDedicatedComparison?.(comparison)) {
    return;
  }
  writeAtom(currentComparisonMode, {comparison, visible: true, focusedFile});
}

export function dismissComparison() {
  writeAtom(currentComparisonMode, last => ({...last, visible: false, focusedFile: undefined}));
}
