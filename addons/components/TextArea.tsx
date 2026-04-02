/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';

import {useId} from 'react';
import {cn} from 'shared/cn';
import {Column} from './Flex';
import css from './TextArea.module.css';

export type TextAreaProps = {
  children?: ReactNode;
  className?: string;
  containerClassName?: string;
  resize?: 'none' | 'vertical' | 'horizontal' | 'both';
  ref?: React.Ref<HTMLTextAreaElement>;
} & React.DetailedHTMLProps<React.TextareaHTMLAttributes<HTMLTextAreaElement>, HTMLTextAreaElement>;

export function TextArea({
  children,
  className: classNameProp,
  containerClassName,
  resize = 'none',
  ref,
  ...rest
}: TextAreaProps) {
  const id = useId();
  return (
    <Column className={cn(css.root, containerClassName)} alignStart>
      {children && (
        <label htmlFor={id} className={css.label}>
          {children}
        </label>
      )}
      <textarea
        ref={ref}
        style={{resize}}
        className={cn(css.textarea, classNameProp)}
        id={id}
        {...rest}
      />
    </Column>
  );
}
