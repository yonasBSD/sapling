/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';
import type {ColumnAlignmentProps} from './Flex';

import {cn} from 'shared/cn';
import {Column, Row} from './Flex';
import css from './Panels.module.css';

export type PanelInfo = {render: () => ReactNode; label: ReactNode};
export function Panels<T extends string>({
  panels,
  className,
  tabClassName,
  tabListClassName,
  alignmentProps,
  active,
  onSelect,
  tabListOptionalComponent,
}: {
  panels: Record<T, PanelInfo>;
  className?: string;
  tabClassName?: string;
  tabListClassName?: string;
  alignmentProps?: ColumnAlignmentProps;
  active: T;
  onSelect: (item: T) => void;
  tabListOptionalComponent?: ReactNode;
}) {
  return (
    <Column className={className} {...(alignmentProps ?? {alignStart: true})}>
      <Row className={cn(css.tabList, css.spaceBetween, tabListClassName)} role="tablist">
        <Row>
          {(Object.entries(panels) as Array<[T, PanelInfo]>).map(([name, value]) => {
            return (
              <button
                role="tab"
                aria-selected={active === name}
                key={name}
                onClick={() => onSelect(name)}
                className={cn(css.tab, active === name && css.activeTab, tabClassName)}>
                {value.label}
              </button>
            );
          })}
        </Row>
        {tabListOptionalComponent}
      </Row>
      <div role="tabpanel" className={css.tabpanel}>
        {panels[active]?.render()}
      </div>
    </Column>
  );
}
