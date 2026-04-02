/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {Button} from 'isl-components/Button';
import {Tooltip} from 'isl-components/Tooltip';
import {t, T} from 'isl/src/i18n';
import serverApi from '../../isl/src/ClientToServerAPI';
import css from './AddMoreCwdsHint.module.css';

export default function AddMoreCwdsHint() {
  return (
    <Tooltip
      title={t(
        'ISL can switch between any repositories that are mounted VS Code workspace folders.\n\n' +
          'Click to add another VS Code workspace folder.',
      )}>
      <Button
        className={css.wideButton}
        onClick={() => {
          serverApi.postMessage({
            type: 'platform/executeVSCodeCommand',
            command: 'workbench.action.addRootFolder',
            args: [],
          });
        }}>
        <T>Add Folder to Workspace</T>
      </Button>
    </Tooltip>
  );
}
