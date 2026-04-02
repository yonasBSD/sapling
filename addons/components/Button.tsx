/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ExclusiveOr} from './Types';
import type {ReactProps} from './utils';

import {type ReactNode} from 'react';
import {cn} from 'shared/cn';
import css from './Button.module.css';
import {layout} from './theme/layout';
export {default as buttonStyles} from './Button.module.css';

export function Button({
  icon: iconProp,
  primary: primaryProp,
  disabled,
  onClick,
  children,
  className,
  kind,
  ref,
  ...rest
}: {
  className?: string;
  children?: ReactNode;
  disabled?: boolean;
  primary?: boolean;
  icon?: boolean;
  ref?: React.Ref<HTMLButtonElement>;
} & Omit<ReactProps<HTMLButtonElement>, 'className'> &
  ExclusiveOr<
    ExclusiveOr<
      {
        /**
         * Render as a bright button, encouraged the primary confirmation action.
         * Equivalent to kind='primary'.
         */
        primary?: boolean;
      },
      {
        /**
         * Render as a smaller, more subtle button. Useful in toolbars or when using an icon instead of a label.
         * Equivalent to kind='icon'.
         */
        icon?: boolean;
      }
    >,
    /** How to display the button. Can also provide `primary` or `icon` shorthand bool props instead. */
    {kind?: 'primary' | 'icon' | undefined}
  >) {
  const primary = kind === 'primary' || primaryProp === true;
  const icon = kind === 'icon' || iconProp === true;
  return (
    <button
      tabIndex={disabled ? -1 : 0}
      onClick={e => {
        // don't allow clicking a disabled button
        disabled !== true && onClick?.(e);
      }}
      ref={ref}
      className={cn(
        layout.flexRow,
        css.button,
        primary && css.primary,
        icon && css.icon,
        disabled && css.disabled,
        className,
      )}
      disabled={disabled}
      {...rest}>
      {children}
    </button>
  );
}
