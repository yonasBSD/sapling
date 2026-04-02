/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type react from 'react';
import type {ReactProps} from './utils';

import {useEffect, useId, useRef} from 'react';
import {cn} from 'shared/cn';
import css from './Checkbox.module.css';
import {layout} from './theme/layout';

function Checkmark({checked}: {checked: boolean}) {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      xmlns="http://www.w3.org/2000/svg"
      fill={checked ? 'currentColor' : 'transparent'}
      className={css.checkmark}>
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M14.431 3.323l-8.47 10-.79-.036-3.35-4.77.818-.574 2.978 4.24 8.051-9.506.764.646z"></path>
    </svg>
  );
}

function Indeterminate() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      xmlns="http://www.w3.org/2000/svg"
      fill={'currentColor'}
      className={css.checkmark}>
      <rect x="4" y="4" height="8" width="8" rx="2" />
    </svg>
  );
}

export function Checkbox({
  children,
  checked,
  onChange,
  disabled,
  indeterminate,
  className,
  ...rest
}: {
  children?: react.ReactNode;
  checked: boolean;
  /** "indeterminate" state is neither true nor false, and renders as a box instead of a checkmark.
   * Usually represents partial selection of children. */
  indeterminate?: boolean;
  disabled?: boolean;
  onChange?: (checked: boolean) => unknown;
  className?: string;
} & Omit<ReactProps<HTMLInputElement>, 'onChange'>) {
  const id = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  // Indeterminate cannot be set in HTML, use an effect to synchronize
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.indeterminate = indeterminate === true;
    }
  }, [indeterminate]);
  return (
    <label
      htmlFor={id}
      className={cn(
        layout.flexRow,
        css.label,
        children != null && css.withChildren,
        disabled && css.disabled,
        className,
      )}>
      <input
        ref={inputRef}
        type="checkbox"
        id={id}
        checked={checked}
        onChange={e => !disabled && onChange?.(e.target.checked)}
        disabled={disabled}
        className={css.input}
        {...rest}
      />
      {indeterminate === true ? <Indeterminate /> : <Checkmark checked={checked} />}
      {children}
    </label>
  );
}
