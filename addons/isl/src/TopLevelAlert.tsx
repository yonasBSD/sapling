/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {ReactNode} from 'react';
import type {Alert, AlertSeverity} from './types';

import {Banner, BannerKind} from 'isl-components/Banner';
import {Button} from 'isl-components/Button';
import {Icon} from 'isl-components/Icon';
import {Subtle} from 'isl-components/Subtle';
import {layout} from 'isl-components/theme/layout';
import {atom, useAtom, useAtomValue} from 'jotai';
import {useEffect} from 'react';
import {cn} from 'shared/cn';
import serverAPI from './ClientToServerAPI';
import {Link} from './Link';
import css from './TopLevelAlert.module.css';
import {tracker} from './analytics';
import {T} from './i18n';
import {localStorageBackedAtom, writeAtom} from './jotaiUtils';
import {applicationinfo} from './serverAPIState';

const dismissedAlerts = localStorageBackedAtom<{[key: string]: boolean}>(
  'isl.dismissed-alerts',
  {},
);

const activeAlerts = atom<Array<Alert>>([]);

const ALERT_FETCH_INTERVAL_MS = 5 * 60 * 1000;

const alertsAlreadyLogged = new Set<string>();

serverAPI.onMessageOfType('fetchedActiveAlerts', event => {
  writeAtom(activeAlerts, event.alerts);
});
serverAPI.onSetup(() => {
  const fetchAlerts = () =>
    serverAPI.postMessage({
      type: 'fetchActiveAlerts',
    });
  const interval = setInterval(fetchAlerts, ALERT_FETCH_INTERVAL_MS);
  fetchAlerts();
  return () => clearInterval(interval);
});

export function TopLevelAlerts() {
  const [dismissed, setDismissed] = useAtom(dismissedAlerts);
  const alerts = useAtomValue(activeAlerts);
  const info = useAtomValue(applicationinfo);
  const version = info?.version;

  useEffect(() => {
    for (const {key} of alerts) {
      if (!alertsAlreadyLogged.has(key)) {
        tracker.track('AlertShown', {extras: {key}});
        alertsAlreadyLogged.add(key);
      }
    }
  }, [alerts]);

  return (
    <div>
      {alerts
        .filter(
          alert =>
            dismissed[alert.key] !== true &&
            (alert['isl-version-regex'] == null ||
              (version != null && new RegExp(alert['isl-version-regex']).test(version))),
        )
        .map((alert, i) => (
          <TopLevelAlert
            alert={alert}
            key={i}
            onDismiss={() => {
              setDismissed(old => ({...old, [alert.key]: true}));
              tracker.track('AlertDismissed', {extras: {key: alert.key}});
            }}
          />
        ))}
    </div>
  );
}

const sevClassMap: Record<AlertSeverity, string> = {
  'SEV 0': css.sev0,
  'SEV 1': css.sev1,
  'SEV 2': css.sev2,
  'SEV 3': css.sev3,
  'SEV 4': css.sev4,
  UBN: css.ubn,
};

function SevBadge({children, severity}: {children: ReactNode; severity: AlertSeverity}) {
  return <span className={cn(css.sev, sevClassMap[severity])}>{children}</span>;
}

function TopLevelAlert({alert, onDismiss}: {alert: Alert; onDismiss: () => unknown}) {
  const {title, description, url, severity} = alert;
  return (
    <div className={css.alertContainer}>
      <Banner kind={BannerKind.default} icon={<Icon icon="flame" size="M" color="red" />}>
        <div className={cn(layout.flexCol, css.alert)}>
          <div className={css.dismissX}>
            <Button onClick={onDismiss} data-testid="dismiss-alert">
              <Icon icon="x" />
            </Button>
          </div>
          <b>
            <T>Ongoing Issue</T>
          </b>
          <span className={cn(layout.flexRow, css.alertContent)}>
            <SevBadge severity={severity}>{severity}</SevBadge> <Link href={url}>{title}</Link>
            <Icon icon="link-external" />
          </span>
          <Subtle>{description}</Subtle>
        </div>
      </Banner>
    </div>
  );
}
