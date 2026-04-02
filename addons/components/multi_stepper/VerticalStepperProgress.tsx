/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {MultiStepperContext} from 'isl-components/multi_stepper/MultiStepperContext';

import {Icon} from 'isl-components/Icon';
import {cn} from 'shared/cn';
import css from './VerticalStepperProgress.module.css';

type Props<TKey> = {
  stepper: MultiStepperContext<TKey>;
};

/**
 * A vertical progress bar for a multi-step stepper.
 */
export function VerticalStepperProgress<TKey>({stepper}: Props<TKey>) {
  const icon = <Icon icon="check" />;

  const steps = stepper.getAllSteps();
  const currentIndex = stepper.getStepIndex();

  return (
    <div>
      {steps.map((step, index) => {
        const isActive = index === currentIndex;
        const isCompleted = index < currentIndex;

        return (
          <div
            key={String(step.key)}
            onClick={() => (isCompleted ? stepper.goToStepByKey(step.key) : undefined)}
            className={cn(
              css.stepItem,
              isActive && css.stepItemActive,
              isCompleted && css.stepItemCompleted,
            )}>
            <div
              className={cn(
                css.stepNumber,
                isActive && css.stepNumberActive,
                isCompleted && css.stepNumberCompleted,
              )}>
              {isCompleted ? icon : index + 1}
            </div>
            <div className={cn(css.stepLabel, isActive && css.stepLabelActive)}>{step.label}</div>
          </div>
        );
      })}
    </div>
  );
}
