/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';
import type {ReactProps} from './utils';

import {useId} from 'react';
import {cn} from 'shared/cn';
import css from './Dropdown.module.css';

export function Dropdown<T extends string | {value: string; name: string; disabled?: boolean}>({
  options,
  children,
  className,
  value,
  disabled,
  ...rest
}: {
  options: Array<T>;
  children?: ReactNode;
  value?: T extends string ? T : T extends {value: string; name: string} ? T['value'] : never;
  disabled?: boolean;
  className?: string;
} & ReactProps<HTMLSelectElement>) {
  const id = useId();
  return (
    <select
      className={cn(css.select, className, disabled && css.disabled)}
      {...rest}
      disabled={disabled || options.length === 0}
      value={value}>
      {children && (
        <label htmlFor={id} className={css.label}>
          {children}
        </label>
      )}
      {options.map((option, index) => {
        const val = typeof option === 'string' ? option : option.value;
        const name = typeof option === 'string' ? option : option.name;
        const disabled = typeof option === 'string' ? false : option.disabled;
        return (
          <option key={index} value={val} disabled={disabled}>
            {name}
          </option>
        );
      })}
    </select>
  );
}
