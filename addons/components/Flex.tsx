/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactProps} from './utils';

import {cn} from 'shared/cn';
import css from './Flex.module.css';

type ContainerProps = ReactProps<HTMLDivElement>;

export type ColumnAlignmentProps =
  | {alignStart: true; alignCenter?: undefined | false; alignItems?: undefined}
  | {alignStart?: undefined | false; alignCenter?: true; alignItems?: undefined}
  | {
      alignStart?: undefined | false;
      alignCenter?: undefined | false;
      alignItems: 'stretch' | 'normal' | 'end';
    };

/** Vertical flex layout */
export function Column(props: ContainerProps & ColumnAlignmentProps) {
  const {alignStart, alignCenter, alignItems, className, style, ...rest} = props;

  return (
    <div
      {...rest}
      className={cn(
        css.flex,
        css.column,
        alignStart && css.alignStart,
        alignCenter && css.alignCenter,
        className,
      )}
      style={alignItems ? {...(style ?? {}), alignItems} : style}
    />
  );
}

/** Horizontal flex layout */
export function Row({className, ...rest}: ContainerProps) {
  return <div {...rest} className={cn(css.flex, css.row, className)} />;
}

/** Visually empty flex item with `flex-grow: 1` to insert as much space as possible between siblings. */
export function FlexSpacer() {
  return <div className={css.spacer} />;
}
