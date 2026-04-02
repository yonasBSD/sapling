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
import {Column} from './Flex';
import css from './TextField.module.css';
export {default as textFieldStyles} from './TextField.module.css';

export function TextField({
  children,
  className: classNameProp,
  containerClassName,
  value,
  width,
  ref,
  ...rest
}: {
  children?: ReactNode;
  className?: string;
  containerClassName?: string;
  value?: string;
  width?: string;
  placeholder?: string;
  readOnly?: boolean;
  ref?: React.Ref<HTMLInputElement>;
} & ReactProps<HTMLInputElement>) {
  const id = useId();
  return (
    <Column className={cn(css.root, containerClassName)} style={{width}} alignStart>
      {children && (
        <label htmlFor={id} className={css.label}>
          {children}
        </label>
      )}
      <input
        className={cn(css.input, classNameProp)}
        type="text"
        id={id}
        value={value}
        {...rest}
        ref={ref}
      />
    </Column>
  );
}
