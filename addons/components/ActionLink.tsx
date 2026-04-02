/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import css from './ActionLink.module.css';

export default function ActionLink({
  onClick,
  children,
  title,
}: {
  onClick: () => void;
  title?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={css.button} onClick={() => onClick()} title={title}>
      {children}
    </div>
  );
}
