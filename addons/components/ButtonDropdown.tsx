/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';

import {cn} from 'shared/cn';
import {Button, buttonStyles} from './Button';
import css from './ButtonDropdown.module.css';
import {Icon} from './Icon';
import {Tooltip, type TooltipProps} from './Tooltip';
export {default as styles} from './ButtonDropdown.module.css';

export function ButtonDropdown<T extends {label: ReactNode; id: string}>({
  options,
  kind,
  onClick,
  selected,
  onChangeSelected,
  buttonDisabled,
  pickerDisabled,
  icon,
  customSelectComponent,
  primaryTooltip,
  ...rest
}: {
  options: ReadonlyArray<T>;
  kind?: 'primary' | 'icon' | undefined;
  onClick: (selected: T, event: React.MouseEvent<HTMLButtonElement>) => unknown;
  selected: T;
  onChangeSelected: (newSelected: T) => unknown;
  buttonDisabled?: boolean;
  pickerDisabled?: boolean;
  /** Icon to place in the button */
  icon?: React.ReactNode;
  customSelectComponent?: React.ReactNode;
  primaryTooltip?: TooltipProps;
  'data-testId'?: string;
}) {
  const selectedOption = options.find(opt => opt.id === selected.id) ?? options[0];

  const buttonComponent = (
    <Button
      kind={kind}
      onClick={buttonDisabled ? undefined : e => onClick(selected, e)}
      disabled={buttonDisabled}
      className={cn(css.button, kind === 'icon' && css.iconButton)}
      {...rest}>
      {icon ?? null} {selected.label}
    </Button>
  );

  return (
    <div className={css.container}>
      {primaryTooltip ? <Tooltip {...primaryTooltip}>{buttonComponent}</Tooltip> : buttonComponent}
      {customSelectComponent ?? (
        <select
          className={cn(
            css.select,
            kind === 'icon' && buttonStyles.icon,
            kind === 'icon' && css.iconSelect,
          )}
          disabled={pickerDisabled}
          value={selectedOption.id}
          onClick={e => e.stopPropagation()}
          onChange={event => {
            const matching = options.find(opt => opt.id === (event.target.value as T['id']));
            if (matching != null) {
              onChangeSelected(matching);
            }
          }}>
          {options.map(option => (
            <option key={option.id} value={option.id}>
              {option.label}
            </option>
          ))}
        </select>
      )}
      <Icon
        icon="chevron-down"
        className={cn(
          css.chevron,
          kind === 'icon' && css.iconChevron,
          pickerDisabled && css.chevronDisabled,
        )}
      />
    </div>
  );
}
