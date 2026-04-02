/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {cn} from 'shared/cn';
import css from './Link.module.css';
import platform from './platform';

export function Link({
  children,
  href,
  onClick,
  className,
  ...rest
}: React.DetailedHTMLProps<React.AnchorHTMLAttributes<HTMLAnchorElement>, HTMLAnchorElement> & {
  className?: string;
}) {
  const handleClick = (
    event: React.MouseEvent<HTMLAnchorElement> | React.KeyboardEvent<HTMLAnchorElement>,
  ) => {
    // allow pressing Enter when focused to simulate clicking for accessibility
    if (event.type === 'keyup') {
      if ((event as React.KeyboardEvent<HTMLAnchorElement>).key !== 'Enter') {
        return;
      }
    }
    if (href) {
      platform.openExternalLink(href);
    }
    onClick?.(event as React.MouseEvent<HTMLAnchorElement>);
    event.preventDefault();
    event.stopPropagation();
  };
  return (
    <a
      href={href}
      tabIndex={0}
      onKeyUp={handleClick}
      onClick={handleClick}
      className={cn(css.a, className)}
      {...rest}>
      {children}
    </a>
  );
}
