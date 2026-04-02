/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';
import type {ReactProps} from './utils';

import {cn} from 'shared/cn';
import css from './Tag.module.css';

export function Tag({
  className,
  ...rest
}: {children: ReactNode; className?: string} & ReactProps<HTMLSpanElement>) {
  return <span className={cn(css.tag, className)} {...rest} />;
}
