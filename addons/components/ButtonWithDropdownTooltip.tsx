/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {type ReactNode} from 'react';

import {cn} from 'shared/cn';
import {Button} from './Button';
import css from './ButtonWithDropdownTooltip.module.css';
import {Icon} from './Icon';
import {Tooltip} from './Tooltip';

export function ButtonWithDropdownTooltip({
  label,
  kind,
  onClick,
  disabled,
  icon,
  tooltip,
  ref,
  ...rest
}: {
  label: ReactNode;
  kind?: 'primary' | 'icon' | undefined;
  onClick: () => unknown;
  disabled?: boolean;
  icon?: React.ReactNode;
  tooltip: React.ReactNode;
  'data-testId'?: string;
  ref?: React.Ref<HTMLButtonElement>;
}) {
  return (
    <div className={css.container}>
      <Button
        kind={kind}
        onClick={disabled ? undefined : () => onClick()}
        disabled={disabled}
        className={cn(css.button, kind === 'icon' && css.iconButton)}
        ref={ref}
        {...rest}>
        {icon ?? null} {label}
      </Button>
      <Tooltip
        trigger="click"
        component={_dismiss => <div>{tooltip}</div>}
        group="topbar"
        placement="bottom">
        <Button
          kind={kind}
          onClick={undefined}
          disabled={disabled}
          className={css.chevron}
          {...rest}>
          <Icon icon="chevron-down" className={cn(css.chevron, disabled && css.chevronDisabled)} />
        </Button>
      </Tooltip>
    </div>
  );
}
