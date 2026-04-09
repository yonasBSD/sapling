/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {
  AbsolutePath,
  CwdInfo,
  CwdRelativePath,
  RepoRelativePath,
  Submodule,
  SubmodulesByRoot,
  WorktreeEntry,
} from './types';

import {Badge} from 'isl-components/Badge';
import {Button, buttonStyles} from 'isl-components/Button';
import {ButtonDropdown} from 'isl-components/ButtonDropdown';
import {Checkbox} from 'isl-components/Checkbox';
import {Divider} from 'isl-components/Divider';
import {Icon} from 'isl-components/Icon';
import {Kbd} from 'isl-components/Kbd';
import {KeyCode, Modifier} from 'isl-components/KeyboardShortcuts';
import {RadioGroup} from 'isl-components/Radio';
import {Subtle} from 'isl-components/Subtle';
import {TextField} from 'isl-components/TextField';
import {Tooltip} from 'isl-components/Tooltip';
import {atom, useAtomValue} from 'jotai';
import {Suspense, useCallback, useState} from 'react';
import {cn} from 'shared/cn';
import {basename, dirname} from 'shared/utils';
import serverAPI from './ClientToServerAPI';
import {Column, Row, ScrollY} from './ComponentUtils';
import css from './CwdSelector.module.css';
import {DropdownField, DropdownFields} from './DropdownFields';
import {useCommandEvent} from './ISLShortcuts';
import {Internal} from './Internal';
import {codeReviewProvider} from './codeReview/CodeReviewInfo';
import {useFeatureFlagSync} from './featureFlags';
import {T, t} from './i18n';
import {writeAtom} from './jotaiUtils';
import {AddWorktreeOperation} from './operations/AddWorktreeOperation';
import {RemoveWorktreeOperation} from './operations/RemoveWorktreeOperation';
import {useRunOperation} from './operationsState';
import platform from './platform';
import {serverCwd} from './repositoryData';
import {repositoryInfo, submodulesByRoot, worktreeInfoData} from './serverAPIState';
import {useModal} from './useModal';
import {registerCleanup, registerDisposable} from './utils';

/**
 * Give the relative path to `path` from `root`
 * For example, relativePath('/home/user', '/home') -> 'user'
 */
export function relativePath(root: AbsolutePath, path: AbsolutePath) {
  if (root == null || path === '') {
    return '';
  }
  const sep = guessPathSep(path);
  return maybeTrimPrefix(path.replace(root, ''), sep);
}

/**
 * Simple version of path.join()
 * Expect an absolute root path and a relative path
 * e.g.
 * joinPaths('/home', 'user') -> '/home/user'
 * joinPaths('/home/', 'user/.config') -> '/home/user/.config'
 */
export function joinPaths(root: AbsolutePath, path: CwdRelativePath, sep = '/'): AbsolutePath {
  return root.endsWith(sep) ? root + path : root + sep + path;
}

/**
 * Trim a suffix if it exists
 * maybeTrimSuffix('abc/', '/') -> 'abc'
 * maybeTrimSuffix('abc', '/') -> 'abc'
 */
function maybeTrimSuffix(s: string, c: string): string {
  return s.endsWith(c) ? s.slice(0, -c.length) : s;
}

function maybeTrimPrefix(s: string, c: string): string {
  return s.startsWith(c) ? s.slice(c.length) : s;
}

function getMainSelectorLabel(
  directRepoRoot: AbsolutePath,
  nestedRepoRoots: AbsolutePath[] | undefined,
  cwd: string,
) {
  const sep = guessPathSep(cwd);

  // If there are multiple nested repo roots,
  // show the first one as there will be following selectors for the rest
  if (nestedRepoRoots && nestedRepoRoots.length > 1) {
    return maybeTrimSuffix(basename(nestedRepoRoots[0], sep), sep);
  }

  // Otherwise, build the label with the direct and only repo root
  const repoBasename = maybeTrimSuffix(basename(directRepoRoot, sep), sep);
  const repoRelativeCwd = relativePath(directRepoRoot, cwd);
  if (repoRelativeCwd === '') {
    return repoBasename;
  }
  return joinPaths(repoBasename, repoRelativeCwd, sep);
}

export const availableCwds = atom<Array<CwdInfo>>([]);
registerCleanup(
  availableCwds,
  serverAPI.onConnectOrReconnect(() => {
    serverAPI.postMessage({
      type: 'platform/subscribeToAvailableCwds',
    });
  }),
  import.meta.hot,
);

registerDisposable(
  availableCwds,
  serverAPI.onMessageOfType('platform/availableCwds', event =>
    writeAtom(availableCwds, event.options),
  ),
  import.meta.hot,
);

registerDisposable(
  availableCwds,
  serverAPI.onMessageOfType('changeActiveRepo', event => {
    changeCwd(event.cwd);
  }),
  import.meta.hot,
);

export function CwdSelector() {
  const info = useAtomValue(repositoryInfo);
  const currentCwd = useAtomValue(serverCwd);
  const submodulesMap = useAtomValue(submodulesByRoot);

  if (info == null) {
    return null;
  }
  // The most direct root of the cwd
  const repoRoot = info.repoRoot;
  // The list of repo roots down to the cwd, in order from furthest to closest
  const repoRoots = info.repoRoots;

  const mainLabel = getMainSelectorLabel(repoRoot, repoRoots, currentCwd);

  return (
    <div className={css.container}>
      <MainCwdSelector
        currentCwd={currentCwd}
        label={mainLabel}
        hideRightBorder={
          (repoRoots && repoRoots.length > 1) ||
          (submodulesMap?.get(repoRoot)?.value?.filter(m => m.active).length ?? 0) > 0
        }
      />
      <SubmoduleSelectorGroup repoRoots={repoRoots} submoduleOptions={submodulesMap} />
    </div>
  );
}

/**
 * The leftmost tooltip that can show cwd and repo details.
 */
function MainCwdSelector({
  currentCwd,
  label,
  hideRightBorder,
}: {
  currentCwd: AbsolutePath;
  label: string;
  hideRightBorder: boolean;
}) {
  const allCwdOptions = useCwdOptions();
  const cwdOptions = allCwdOptions.filter(opt => opt.valid);
  const additionalToggles = useCommandEvent('ToggleCwdDropdown');

  return (
    <Tooltip
      trigger="click"
      component={dismiss => <CwdDetails dismiss={dismiss} />}
      additionalToggles={additionalToggles.asEventTarget()}
      group="topbar"
      placement="bottom"
      title={
        <T replace={{$shortcut: <Kbd keycode={KeyCode.C} modifiers={[Modifier.ALT]} />}}>
          Repository info & cwd ($shortcut)
        </T>
      }>
      {hideRightBorder || cwdOptions.length < 2 ? (
        <Button
          icon
          data-testid="cwd-dropdown-button"
          className={hideRightBorder ? css.hideRightBorder : undefined}>
          <Icon icon="folder" />
          {label}
        </Button>
      ) : (
        // use a ButtonDropdown as a shortcut to quickly change cwd
        <ButtonDropdown
          data-testid="cwd-dropdown-button"
          kind="icon"
          options={cwdOptions}
          selected={
            cwdOptions.find(opt => opt.id === currentCwd) ?? {
              id: currentCwd,
              label,
              valid: true,
            }
          }
          icon={<Icon icon="folder" />}
          onClick={
            () => null // fall through to the Tooltip
          }
          onChangeSelected={value => {
            if (value.id !== currentCwd) {
              changeCwd(value.id);
            }
          }}></ButtonDropdown>
      )}
    </Tooltip>
  );
}

function SubmoduleSelectorGroup({
  repoRoots,
  submoduleOptions,
}: {
  repoRoots: AbsolutePath[] | undefined;
  submoduleOptions: SubmodulesByRoot;
}) {
  const currentCwd = useAtomValue(serverCwd);
  if (repoRoots == null) {
    return null;
  }
  const numRoots = repoRoots.length;
  const directRepoRoot = repoRoots[numRoots - 1];
  if (currentCwd !== directRepoRoot) {
    // If the actual cwd is deeper than the supeproject root,
    // submodule selectors don't make sense
    return null;
  }
  const submodulesToBeSelected = submoduleOptions.get(directRepoRoot)?.value?.filter(m => m.active);

  const out = [];

  for (let i = 1; i < numRoots; i++) {
    const currRoot = repoRoots[i];
    const prevRoot = repoRoots[i - 1];
    const submodules = submoduleOptions.get(prevRoot)?.value?.filter(m => m.active);
    if (submodules != null && submodules.length > 0) {
      out.push(
        <SubmoduleSelector
          submodules={submodules}
          selected={submodules?.find(opt => opt.path === relativePath(prevRoot, currRoot))}
          onChangeSelected={value => {
            if (value.path !== relativePath(prevRoot, currRoot)) {
              changeCwd(joinPaths(prevRoot, value.path));
            }
          }}
          hideRightBorder={i < numRoots - 1 || submodulesToBeSelected != undefined}
          root={prevRoot}
          key={prevRoot}
        />,
      );
    }
  }

  if (submodulesToBeSelected != null && submodulesToBeSelected.length > 0) {
    out.push(
      <SubmoduleSelector
        submodules={submodulesToBeSelected}
        onChangeSelected={value => {
          if (value.path !== relativePath(directRepoRoot, currentCwd)) {
            changeCwd(joinPaths(directRepoRoot, value.path));
          }
        }}
        hideRightBorder={false}
        root={directRepoRoot}
        key={directRepoRoot}
      />,
    );
  }

  return out;
}

function CwdDetails({dismiss}: {dismiss: () => unknown}) {
  const info = useAtomValue(repositoryInfo);
  const repoRoot = info?.repoRoot ?? null;
  const provider = useAtomValue(codeReviewProvider);
  const cwd = useAtomValue(serverCwd);
  const AddMoreCwdsHint = platform.AddMoreCwdsHint;
  return (
    <DropdownFields title={<T>Repository info</T>} icon="folder" data-testid="cwd-details-dropdown">
      <CwdSelections dismiss={dismiss} divider />
      {AddMoreCwdsHint && (
        <Suspense>
          <AddMoreCwdsHint />
        </Suspense>
      )}
      <DropdownField title={<T>Active working directory</T>}>
        <code>{cwd}</code>
      </DropdownField>
      <DropdownField title={<T>Repository Root</T>}>
        <code>{repoRoot}</code>
      </DropdownField>
      <WorktreeSection dismiss={dismiss} />
      {provider != null ? (
        <DropdownField title={<T>Code Review Provider</T>}>
          <span>
            <Badge>{provider?.name}</Badge> <provider.RepoInfo />
          </span>
        </DropdownField>
      ) : null}
    </DropdownFields>
  );
}

function WorktreeSection({dismiss}: {dismiss: () => unknown}) {
  const worktreesEnabled = useFeatureFlagSync(Internal.featureFlags?.Worktrees);
  const info = useAtomValue(repositoryInfo);
  const worktreeInfo = useAtomValue(worktreeInfoData);
  const repoRoot = info?.repoRoot ?? '';
  const runOperation = useRunOperation();
  const showModal = useModal();
  const [removingPath, setRemovingPath] = useState<string | null>(null);

  // Only show worktrees for EdenFS repos that are not git-based
  if (!worktreesEnabled || info?.isEdenFs !== true || info?.codeReviewSystem.type === 'github') {
    return null;
  }

  const allWorktrees = worktreeInfo?.worktrees ?? [];
  const sortedWorktrees = [...allWorktrees].sort((a, b) => {
    if (a.role === 'main') {
      return -1;
    }
    if (b.role === 'main') {
      return 1;
    }
    return basename(a.path, guessPathSep(a.path)).localeCompare(
      basename(b.path, guessPathSep(b.path)),
    );
  });

  const renderWorktreeRow = (wt: WorktreeEntry) => {
    const isCurrent = pathsAreIdentical(wt.path, repoRoot);
    const wtBasename = basename(wt.path, guessPathSep(wt.path));
    const rowClass = isCurrent ? css.worktreeRowCurrent : css.worktreeRow;
    const hasLabel = wt.label != null && wt.label !== '';
    return (
      <WorktreeRowWithHover
        key={wt.path}
        rowClass={rowClass}
        isCurrent={isCurrent}
        wt={wt}
        wtBasename={wtBasename}
        hasLabel={hasLabel}
        removingPath={removingPath}
        setRemovingPath={setRemovingPath}
        runOperation={runOperation}
        showModal={showModal}
        dismiss={dismiss}
      />
    );
  };

  return (
    <DropdownField
      title={
        <Tooltip
          title={t(
            'Worktrees are lightweight copies of your repository, like branches with their own working copy. Useful for working in parallel on the same machine.',
          )}>
          <Row>
            <T>Worktrees</T> <Icon icon="question" />
          </Row>
        </Tooltip>
      }>
      <div className={css.worktreeSection} data-testid="worktree-section">
        {sortedWorktrees.map(wt => renderWorktreeRow(wt))}
        <AddWorktreeButton
          dismiss={dismiss}
          repoRoot={sortedWorktrees.find(wt => wt.role === 'main')?.path ?? repoRoot}
          existingWorktreePaths={allWorktrees.map(wt => wt.path)}
        />
      </div>
    </DropdownField>
  );
}

function WorktreeRowWithHover({
  rowClass,
  isCurrent,
  wt,
  wtBasename,
  hasLabel,
  removingPath,
  setRemovingPath,
  runOperation,
  showModal,
  dismiss,
}: {
  rowClass: string;
  isCurrent: boolean | undefined;
  wt: WorktreeEntry;
  wtBasename: string;
  hasLabel: boolean;
  removingPath: string | null;
  setRemovingPath: (path: string | null) => void;
  runOperation: ReturnType<typeof useRunOperation>;
  showModal: ReturnType<typeof useModal>;
  dismiss: () => unknown;
}) {
  return (
    <div
      key={wt.path}
      className={rowClass}
      data-testid={isCurrent ? 'current-worktree' : 'sibling-worktree'}>
      <code className={css.worktreePath} title={wt.path}>
        {hasLabel ? wt.label : wtBasename}
      </code>
      {isCurrent ? (
        <Badge className={css.activeBadge}>Active</Badge>
      ) : (
        <div className={css.worktreeActions}>
          <Tooltip title={t('Switch to this worktree')}>
            <Button
              icon
              data-testid="worktree-switch-button"
              onClick={async () => {
                dismiss();
                if (platform.platformName !== 'vscode') {
                  changeCwd(wt.path);
                  return;
                }
                const choice = await showModal({
                  type: 'confirm',
                  title: <T>Switch Worktree</T>,
                  icon: 'worktree',
                  message: (
                    <span>
                      <Row>
                        <T replace={{$path: <code>{wtBasename}</code>}}>
                          Switch to worktree $path?
                        </T>
                      </Row>
                      <Row style={{marginTop: 'var(--pad)'}}>
                        <Subtle>
                          <T>
                            Opening in current window will reload the editor. Unsaved changes will
                            be prompted to save.
                          </T>
                        </Subtle>
                      </Row>
                    </span>
                  ),
                  buttons: [
                    {label: t('Open in Current Window')},
                    {label: t('Open in New Window'), primary: true},
                  ],
                });
                if (choice != null) {
                  if (choice.label === t('Open in New Window')) {
                    serverAPI.postMessage({type: 'platform/openInNewWindow', path: wt.path});
                  } else {
                    serverAPI.postMessage({type: 'platform/openFolder', path: wt.path});
                  }
                }
              }}>
              <Icon icon="arrow-swap" />
            </Button>
          </Tooltip>
          {wt.role === 'main' ? (
            <Tooltip title={t('The main worktree cannot be removed')}>
              <Button icon disabled data-testid="worktree-remove-button">
                <Icon icon="trash" />
              </Button>
            </Tooltip>
          ) : (
            <Tooltip title={t('Remove this worktree at $path', {replace: {$path: wt.path}})}>
              <Button
                icon
                data-testid="worktree-remove-button"
                disabled={removingPath === wt.path}
                onClick={async () => {
                  setRemovingPath(wt.path);
                  try {
                    await runOperation(new RemoveWorktreeOperation(wt.path), true);
                  } finally {
                    setRemovingPath(null);
                  }
                }}>
                <Icon icon={removingPath === wt.path ? 'loading' : 'trash'} />
              </Button>
            </Tooltip>
          )}
        </div>
      )}
    </div>
  );
}
function AddWorktreeButton({
  dismiss,
  repoRoot,
  existingWorktreePaths,
}: {
  dismiss: () => unknown;
  repoRoot: string;
  existingWorktreePaths: string[];
}) {
  const showModal = useModal();
  const runOperation = useRunOperation();
  const sep = guessPathSep(repoRoot);
  const parentDir = dirname(repoRoot, sep);
  const repoName = basename(repoRoot, sep);
  const existingBasenames = new Set(existingWorktreePaths.map(p => basename(p, guessPathSep(p))));
  let suffix = 2;
  while (existingBasenames.has(`${repoName}_${suffix}`)) {
    suffix++;
  }
  const defaultDest = `${parentDir}${sep}${repoName}.worktrees${sep}${repoName}_${suffix}`;

  const onClickAdd = useCallback(async () => {
    dismiss();
    const result = await showModal<AddWorktreeResult>({
      type: 'custom',
      title: (
        <Row>
          <T>Add Worktree</T>{' '}
          <Tooltip
            title={t(
              'Worktrees are lightweight copies of your repository, like branches with their own working copy. Useful for working in parallel on the same machine.',
            )}>
            <Icon icon="question" />
          </Tooltip>
        </Row>
      ),
      icon: 'worktree',
      maxWidth: 500,
      component: ({returnResultAndDismiss}) => (
        <AddWorktreeModal
          returnResultAndDismiss={returnResultAndDismiss}
          defaultDest={defaultDest}
        />
      ),
    });
    if (result != null) {
      const spinnerDismiss = await new Promise<() => void>(resolve => {
        showModal({
          type: 'custom',
          title: <T>Creating Worktree</T>,
          icon: 'worktree',
          component: ({returnResultAndDismiss}) => {
            resolve(() => returnResultAndDismiss(undefined));
            return (
              <div className={css.worktreeSpinner}>
                <Icon icon="loading" />
                <T>Creating worktree at</T> <code>{result.destPath}</code>
              </div>
            );
          },
        });
      });
      try {
        await runOperation(
          new AddWorktreeOperation(result.destPath, result.label || undefined),
          true,
        );
      } finally {
        spinnerDismiss();
      }
      if (result.openIn === 'current') {
        changeCwd(result.destPath);
      } else if (result.openIn === 'new') {
        serverAPI.postMessage({type: 'platform/openInNewWindow', path: result.destPath});
      }
    }
  }, [dismiss, showModal, runOperation, defaultDest]);

  return (
    <Button
      data-testid="add-worktree-button"
      className={css.addWorktreeButton}
      onClick={onClickAdd}>
      <Icon icon="plus" /> <T>Add Worktree</T>
    </Button>
  );
}

type AddWorktreeResult = {
  destPath: string;
  label: string;
  openIn: 'current' | 'new' | 'none';
};

function AddWorktreeModal({
  returnResultAndDismiss,
  defaultDest,
}: {
  returnResultAndDismiss: (result: AddWorktreeResult) => void;
  defaultDest: string;
}) {
  const [destPath, setDestPath] = useState(defaultDest);
  const [label, setLabel] = useState('');
  const isVSCode = platform.platformName === 'vscode';
  const [openIn, setOpenIn] = useState<AddWorktreeResult['openIn']>(isVSCode ? 'new' : 'none');
  const [activate, setActivate] = useState(false);
  const [isEditingPath, setIsEditingPath] = useState(false);

  return (
    <div className={css.addWorktreeForm} data-testid="add-worktree-form">
      <TextField
        data-testid="add-worktree-label"
        placeholder={t('Label (optional)')}
        value={label}
        onInput={e => setLabel(e.currentTarget?.value ?? '')}
      />
      <div className={css.worktreeLocationSection}>
        <Subtle className={css.worktreeLocationLabel}>
          <Tooltip title={<T>Location on disk where the worktree files will be created</T>}>
            <T>Worktree root path</T>
          </Tooltip>
        </Subtle>
        {isEditingPath ? (
          <TextField
            data-testid="add-worktree-path"
            value={destPath}
            onInput={e => setDestPath(e.currentTarget?.value ?? '')}
            onBlur={() => setIsEditingPath(false)}
            autoFocus
          />
        ) : (
          <div
            className={css.worktreePathDisplay}
            onClick={() => setIsEditingPath(true)}
            data-testid="add-worktree-edit-path">
            <code className={css.worktreePathText}>{destPath}</code>
            <Icon icon="edit" className={css.worktreePathEditIcon} />
          </div>
        )}
      </div>
      {isVSCode ? (
        <RadioGroup
          choices={
            [
              {
                title: (
                  <Row>
                    <T>Open in new window</T>
                    <Badge>Recommended</Badge>
                  </Row>
                ),
                value: 'new',
              },
              {
                title: <T>Open in current window</T>,
                value: 'current',
              },
              {title: <T>Don't open</T>, value: 'none'},
            ] as const
          }
          current={openIn}
          onChange={setOpenIn}
        />
      ) : (
        <Checkbox
          checked={activate}
          onChange={checked => {
            setActivate(checked);
            setOpenIn(checked ? 'current' : 'none');
          }}>
          <T>Activate</T>
        </Checkbox>
      )}
      <div className={css.addWorktreeFormActions}>
        <Button
          primary
          data-testid="add-worktree-submit"
          disabled={destPath.trim() === ''}
          onClick={() =>
            returnResultAndDismiss({
              destPath: destPath.trim(),
              label: label.trim(),
              openIn,
            })
          }>
          <T>Create</T>
        </Button>
      </div>
    </div>
  );
}

function changeCwd(newCwd: string) {
  serverAPI.postMessage({
    type: 'changeCwd',
    cwd: newCwd,
  });
  serverAPI.cwdChanged();
}

function useCwdOptions() {
  const cwdOptions = useAtomValue(availableCwds);

  return cwdOptions.map((cwd, index) => ({
    id: cwdOptions[index].cwd,
    label: cwd.repoRelativeCwdLabel ?? cwd.cwd,
    valid: cwd.repoRoot != null,
  }));
}

function guessPathSep(path: string): '/' | '\\' {
  if (path.includes('\\')) {
    return '\\';
  } else {
    return '/';
  }
}

function pathsAreIdentical(path1: string, path2: string): boolean {
  const normalizedPath1 = path1.replaceAll('\\', '/');
  const normalizedPath2 = path2.replaceAll('\\', '/');

  const isWindowsAbsolutePath = (path: string) => /^[A-Za-z]:\//.test(path);
  if (isWindowsAbsolutePath(normalizedPath1) && isWindowsAbsolutePath(normalizedPath2)) {
    return normalizedPath1.toLowerCase() === normalizedPath2.toLowerCase();
  }

  return normalizedPath1 === normalizedPath2;
}

export function CwdSelections({dismiss, divider}: {dismiss: () => unknown; divider?: boolean}) {
  const currentCwd = useAtomValue(serverCwd);
  const options = useCwdOptions();
  if (options.length < 2) {
    return null;
  }

  return (
    <DropdownField title={<T>Change active working directory</T>}>
      <RadioGroup
        choices={options.map(({id, label, valid}) => ({
          title: valid ? (
            label
          ) : (
            <Row key={id}>
              {label}{' '}
              <Subtle>
                <T>Not a valid repository</T>
              </Subtle>
            </Row>
          ),
          value: id,
          tooltip: valid
            ? id
            : t('Path $path does not appear to be a valid Sapling repository', {
                replace: {$path: id},
              }),
          disabled: !valid,
        }))}
        current={currentCwd}
        onChange={newCwd => {
          if (newCwd === currentCwd) {
            // nothing to change
            return;
          }
          changeCwd(newCwd);
          dismiss();
        }}
      />
      {divider && <Divider />}
    </DropdownField>
  );
}

/**
 * Dropdown selector for submodules in a breadcrumb style.
 */
function SubmoduleSelector({
  submodules,
  selected,
  onChangeSelected,
  root,
  hideRightBorder = true,
}: {
  submodules: ReadonlyArray<Submodule>;
  selected?: Submodule;
  onChangeSelected: (newSelected: Submodule) => unknown;
  root: AbsolutePath;
  hideRightBorder?: boolean;
}) {
  const selectedValue = submodules.find(m => m.path === selected?.path)?.path;
  const [query, setQuery] = useState('');
  const toDisplay = submodules
    .filter(m => m.name.toLowerCase().includes(query.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name));

  return (
    <>
      <Icon
        icon="chevron-right"
        className={cn(
          buttonStyles.icon,
          css.submoduleSeparator,
          css.hideLeftBorder,
          css.hideRightBorder,
        )}
      />
      <Tooltip
        trigger="click"
        placement="bottom"
        title={<SubmoduleHint path={selectedValue} root={root} />}
        component={dismiss => (
          <Column className={css.submoduleDropdownContainer}>
            <TextField
              autoFocus
              width="100%"
              placeholder={t('search submodule name')}
              value={query}
              onInput={e => setQuery(e.currentTarget?.value ?? '')}
            />
            <div className={css.submoduleList}>
              <ScrollY maxSize={360}>
                {toDisplay.map(m => (
                  <div
                    key={m.path}
                    className={css.submoduleOption}
                    onClick={() => {
                      onChangeSelected(m);
                      setQuery('');
                      dismiss();
                    }}
                    title={m.path}>
                    {m.name}
                  </div>
                ))}
              </ScrollY>
            </div>
          </Column>
        )}>
        <Button
          kind="icon"
          className={cn(
            css.submoduleSelect,
            css.hideLeftBorder,
            hideRightBorder && css.hideRightBorder,
          )}>
          {selected ? selected.name : `${t('submodules')}...`}
        </Button>
      </Tooltip>
    </>
  );
}

function SubmoduleHint({path, root}: {path: RepoRelativePath | undefined; root: AbsolutePath}) {
  return (
    <T>{path ? `${t('Submodule at')}: ${path}` : `${t('Select a submodule under')}: ${root}`}</T>
  );
}
