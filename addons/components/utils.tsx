/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

export type ReactProps<T extends HTMLElement> = React.DetailedHTMLProps<React.HTMLAttributes<T>, T>;

export function findParentWithClassName(
  start: HTMLElement,
  className: string,
): HTMLElement | undefined {
  let el = start as HTMLElement | null;
  while (el) {
    if (el.classList?.contains(className)) {
      return el;
    } else {
      el = el.parentElement;
    }
  }
  return undefined;
}
