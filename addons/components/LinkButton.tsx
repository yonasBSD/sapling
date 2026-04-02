/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';

import {cn} from 'shared/cn';
import css from './LinkButton.module.css';

export function LinkButton({
  children,
  onClick,
  className,
}: {
  children: ReactNode;
  onClick: () => unknown;
  className?: string;
}) {
  return (
    <button className={cn(css.linkButton, className)} onClick={onClick}>
      {children}
    </button>
  );
}
