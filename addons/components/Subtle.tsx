/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {cn} from 'shared/cn';
import css from './Subtle.module.css';

export function Subtle({
  children,
  className,
  ...props
}: React.DetailedHTMLProps<React.HTMLAttributes<HTMLSpanElement>, HTMLSpanElement>) {
  return (
    <span className={cn(css.subtle, className)} {...props}>
      {children}
    </span>
  );
}
