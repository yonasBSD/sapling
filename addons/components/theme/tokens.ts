/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

/**
 * TypeScript constants for CSS custom property references.
 * Use these in CSS module `composes`, inline styles, or anywhere a CSS value is needed.
 *
 * These mirror the custom properties defined in tokens.css.
 */

export const colors = {
  bg: 'var(--color-bg)',
  fg: 'var(--color-fg)',
  brightFg: 'var(--color-bright-fg)',
  focusBorder: 'var(--color-focus-border)',

  hoverDarken: 'var(--color-hover-darken)',
  subtleHoverDarken: 'var(--color-subtle-hover-darken)',
  highlightFg: 'var(--color-highlight-fg)',

  modifiedFg: 'var(--color-modified-fg)',
  addedFg: 'var(--color-added-fg)',
  removedFg: 'var(--color-removed-fg)',
  missingFg: 'var(--color-missing-fg)',

  tooltipBg: 'var(--color-tooltip-bg)',
  tooltipBorder: 'var(--color-tooltip-border)',

  purple: 'var(--color-purple)',
  red: 'var(--color-red)',
  yellow: 'var(--color-yellow)',
  orange: 'var(--color-orange)',
  green: 'var(--color-green)',
  blue: 'var(--color-blue)',
  grey: 'var(--color-grey)',

  signalFg: 'var(--color-signal-fg)',
  signalGoodBg: 'var(--color-signal-good-bg)',
  signalMediumBg: 'var(--color-signal-medium-bg)',
  signalBadBg: 'var(--color-signal-bad-bg)',

  errorFg: 'var(--color-error-fg)',
  errorBg: 'var(--color-error-bg)',

  landFg: 'var(--color-land-fg)',
  landBg: 'var(--color-land-bg)',
  landHoverBg: 'var(--color-land-hover-bg)',
} as const;

export const spacing = {
  none: 'var(--spacing-none)',
  quarter: 'var(--spacing-quarter)',
  half: 'var(--spacing-half)',
  pad: 'var(--spacing-pad)',
  double: 'var(--spacing-double)',
  xlarge: 'var(--spacing-xlarge)',
  xxlarge: 'var(--spacing-xxlarge)',
  xxxlarge: 'var(--spacing-xxxlarge)',
} as const;

export const radius = {
  small: 'var(--radius-small)',
  round: 'var(--radius-round)',
  extraround: 'var(--radius-extraround)',
  full: 'var(--radius-full)',
} as const;

export const font = {
  smaller: 'var(--font-smaller)',
  small: 'var(--font-small)',
  normal: 'var(--font-normal)',
  big: 'var(--font-big)',
  bigger: 'var(--font-bigger)',
} as const;
