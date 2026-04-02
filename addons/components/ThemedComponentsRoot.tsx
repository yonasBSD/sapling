/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';

import './theme/light-theme.css';
import './theme/tokens.css';

export function ThemedComponentsRoot({
  theme,
  className,
  children,
}: {
  theme: 'light' | 'dark';
  className?: string;
  children: ReactNode;
}) {
  const themeClass = `${theme}-theme`;
  const fullClassName = [themeClass, className].filter(Boolean).join(' ');
  return <div className={fullClassName}>{children}</div>;
}
