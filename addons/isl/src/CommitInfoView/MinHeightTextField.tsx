/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {TextAreaProps} from 'isl-components/TextArea';

import {TextArea} from 'isl-components/TextArea';
import {useEffect} from 'react';
import {cn} from 'shared/cn';
import {assert} from '../utils';
import css from './MinHeightTextField.module.css';

/**
 * Wrap `TextArea` to auto-resize to minimum height and optionally disallow newlines.
 * Like a `TextField` that has text wrap inside.
 */
export function MinHeightTextField(
  props: TextAreaProps & {
    onInput: (event: {currentTarget: HTMLTextAreaElement}) => unknown;
    keepNewlines?: boolean;
    className?: string;
    containerClassName?: string;
    ref?: React.RefObject<HTMLTextAreaElement | null>;
  },
) {
  const {onInput, keepNewlines, className, ref, ...rest} = props;

  // ref could also be a callback ref; don't bother supporting that right now.
  assert(typeof ref === 'object', 'MinHeightTextArea requires ref object');

  // whenever the value is changed, recompute & apply the minimum height
  useEffect(() => {
    const textarea = ref?.current;
    if (textarea) {
      const resize = () => {
        textarea.style.height = '';
        const scrollheight = textarea.scrollHeight;
        textarea.style.height = `${scrollheight}px`;
        textarea.rows = 1;
      };
      resize();
      const obs = new ResizeObserver(resize);
      obs.observe(textarea);
      return () => obs.unobserve(textarea);
    }
  }, [props.value, ref]);

  return (
    <TextArea
      ref={ref}
      {...rest}
      className={cn(css.minHeight, className)}
      onInput={e => {
        const newValue = e.currentTarget?.value;
        const result = keepNewlines
          ? newValue
          : // remove newlines so this acts like a textField rather than a textArea
            newValue.replace(/(\r|\n)/g, '');
        onInput({
          currentTarget: {
            value: result,
          } as HTMLTextAreaElement,
        });
      }}
    />
  );
}
