/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactProps} from './utils';

import {cn} from 'shared/cn';
import css from './Divider.module.css';

export function Divider({
  className,
}: {
  className?: string;
} & ReactProps<HTMLHRElement>) {
  return <hr className={cn(css.hr, className)} />;
}
