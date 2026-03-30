/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';
import type {ReactProps} from './utils';

import * as stylex from '@stylexjs/stylex';
import {useId} from 'react';
import {Column} from './Flex';

export const textFieldStyles = stylex.create({
  root: {
    gap: 0,
  },
  label: {
    marginBlock: '1px',
  },
  input: {
    boxSizing: 'border-box',
    height: '26px',
    padding: '0 9px',
    marginBlock: 0,
    minWidth: '100px',
    width: '100%',
    backgroundColor: 'var(--input-background)',
    color: 'var(--input-foreground)',
    borderWidth: 1,
    borderStyle: 'solid',
    borderColor: 'var(--dropdown-border)',
    outline: {
      default: 'none',
      ':focus-visible': '1px solid var(--focus-border)',
    },
    outlineOffset: '-1px',
  },
});

export function TextField({
  children,
  xstyle,
  containerXstyle,
  value,
  width,
  ref,
  ...rest
}: {
  children?: ReactNode;
  xstyle?: stylex.StyleXStyles;
  containerXstyle?: stylex.StyleXStyles;
  value?: string;
  width?: string;
  placeholder?: string;
  readOnly?: boolean;
  ref?: React.Ref<HTMLInputElement>;
} & ReactProps<HTMLInputElement>) {
  const id = useId();
  return (
    <Column xstyle={[textFieldStyles.root, containerXstyle ?? null]} style={{width}} alignStart>
      {children && (
        <label htmlFor={id} {...stylex.props(textFieldStyles.label)}>
          {children}
        </label>
      )}
      <input
        {...stylex.props(textFieldStyles.input, xstyle)}
        type="text"
        id={id}
        value={value}
        {...rest}
        ref={ref}
      />
    </Column>
  );
}
