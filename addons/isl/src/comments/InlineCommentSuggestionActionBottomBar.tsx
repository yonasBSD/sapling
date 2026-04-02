/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {Button} from 'isl-components/Button';
import {Row} from 'isl-components/Flex';
import {Icon} from 'isl-components/Icon';
import css from './InlineCommentSuggestionActionBottomBar.module.css';

export default function InlineCommentActionBottomBar({
  resolved = false,
  onAccept,
  onReject,
  acceptLabel,
  rejectLabel,
  isToggle = false,
}: {
  resolved: boolean;
  onAccept: () => unknown;
  onReject: () => unknown;
  acceptLabel?: string;
  rejectLabel?: string;
  isToggle?: boolean;
}) {
  return isToggle ? (
    <Row className={css.actionBarRow}>
      {!resolved ? (
        <Button onClick={onAccept} primary={true}>
          {acceptLabel ? acceptLabel : 'Apply'}
          <Icon icon="check" />
        </Button>
      ) : (
        <Button onClick={onReject}>
          {rejectLabel ? rejectLabel : 'Discard'}
          <Icon icon="close" />
        </Button>
      )}
    </Row>
  ) : (
    <Row className={css.actionBarRow}>
      <Button onClick={onAccept} primary={true}>
        {acceptLabel ? acceptLabel : 'Apply'}
        <Icon icon="check" />
      </Button>
      <Button onClick={onReject}>
        {rejectLabel ? rejectLabel : 'Discard'}
        <Icon icon="close" />
      </Button>
    </Row>
  );
}
