/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import React from 'react';
import {cn} from 'shared/cn';
import css from './ButtonGroup.module.css';

export function ButtonGroup({
  children,
  icon,
  ...rest
}: {
  children: React.ReactNode;
  /** If true, the border between buttons will be colored to match <Button icon> style buttons */
  icon?: boolean;
  'data-testId'?: string;
}) {
  return (
    <div className={cn(css.group, icon && css.icon)} {...rest}>
      {children}
    </div>
  );
}
