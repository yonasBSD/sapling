/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactProps} from './utils';

import {cn} from 'shared/cn';
import css from './HorizontallyGrowingTextField.module.css';
import {textFieldStyles} from './TextField';

/**
 * Like a normal text field / {@link TextField}, but grows horizontally to fit the text.
 */
export function HorizontallyGrowingTextField(
  props: ReactProps<HTMLInputElement> & {
    value?: string;
    placeholder?: string;
    ref?: React.Ref<HTMLInputElement>;
  },
) {
  const {onInput, ref, ...otherProps} = props;

  return (
    <div className={css.horizontalGrowContainer} data-value={otherProps.value}>
      <input
        className={cn(textFieldStyles.input, css.horizontalGrow)}
        type="text"
        ref={ref}
        onInput={e => {
          if ((e.currentTarget.parentNode as HTMLDivElement)?.dataset) {
            // Use `dataset` + `content: attr(data-value)` to size an ::after element,
            // which auto-expands the containing div to fit the text.
            (e.currentTarget.parentNode as HTMLDivElement).dataset.value = e.currentTarget.value;
          }
          onInput?.(e);
        }}
        {...otherProps}
      />
    </div>
  );
}
