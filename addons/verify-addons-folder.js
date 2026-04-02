#!/usr/bin/env node
/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// @ts-check

/* eslint-disable no-console */

const {spawn} = require('child_process');
const path = require('path');
const process = require('process');

const addons = __dirname;
const description = `Verifies the contents of this folder by running tests and linters.

Requirements:
- \`node\` and \`yarn\` are on the \`$PATH\`
- \`yarn install\` has already been run in the addons/ folder
- \`sl\` required to be on the PATH for isl integration tests`;

/**
 * @typedef {{
 *   useVendoredGrammars: boolean;
 *   skipIntegrationTests: boolean;
 * }} Args
 */

class CommandError extends Error {
  /**
   * @param {string[]} command
   * @param {number | null} exitCode
   */
  constructor(command, exitCode) {
    super(`command failed (${exitCode ?? 'unknown'}): ${command.join(' ')}`);
    this.name = 'CommandError';
  }
}

class Timer {
  /** @type {number} */
  #start;

  /**
   * @param {string} message
   */
  constructor(message) {
    this.#start = Date.now();
    console.log(message);
  }

  /**
   * @param {string} message
   */
  report(message) {
    const durationSeconds = (Date.now() - this.#start) / 1000;
    console.log(`${message} in ${durationSeconds.toFixed(2)}s`);
  }
}

/**
 * @returns {Args}
 */
function parseArgs() {
  const args = process.argv.slice(2);

  /** @type {Args} */
  const parsed = {
    useVendoredGrammars: false,
    skipIntegrationTests: false,
  };

  for (const arg of args) {
    switch (arg) {
      case '--use-vendored-grammars':
        parsed.useVendoredGrammars = true;
        break;
      case '--skip-integration-tests':
        parsed.skipIntegrationTests = true;
        break;
      case '-h':
      case '--help':
        printHelp(0);
        break;
      default:
        printHelp(1, `Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

/**
 * @param {number} exitCode
 * @param {string=} errorMessage
 * @returns {never}
 */
function printHelp(exitCode, errorMessage) {
  const lines = [
    'usage: verify-addons-folder.js [--use-vendored-grammars] [--skip-integration-tests]',
    '',
    description,
    '',
    'options:',
    '  --use-vendored-grammars  No-op. Provided for compatibility.',
    "  --skip-integration-tests  Don't run isl integrations tests",
    '  -h, --help                show this help message and exit',
  ];

  const output = lines.join('\n');
  if (errorMessage != null) {
    console.error(errorMessage);
    console.error(output);
  } else {
    console.log(output);
  }
  process.exit(exitCode);
}

/**
 * @param {Args} args
 * @returns {Promise<void>}
 */
async function verify(args) {
  await Promise.all([
    verifyPrettier(),
    verifyShared(),
    verifyComponents(),
    verifyTextmate(),
    verifyIsl(args),
    verifyInternal(),
  ]);
}

/** @returns {Promise<void>} */
async function verifyPrettier() {
  const timer = new Timer('verifying prettier');
  await run(['yarn', 'run', 'prettier-check'], addons);
  timer.report(ok('prettier'));
}

/** @returns {Promise<void>} */
async function verifyShared() {
  const timer = new Timer('verifying shared/');
  await lintAndTest(path.join(addons, 'shared'));
  timer.report(ok('shared/'));
}

/** @returns {Promise<void>} */
async function verifyComponents() {
  const timer = new Timer('verifying components/');
  await lintAndTest(path.join(addons, 'components'));
  timer.report(ok('components/'));
}

/** @returns {Promise<void>} */
async function verifyTextmate() {
  const timer = new Timer('verifying textmate/');
  const textmate = path.join(addons, 'textmate');
  await Promise.all([
    run(['yarn', 'run', 'tsc', '--noEmit'], textmate),
    run(['yarn', 'run', 'lint'], textmate),
  ]);
  timer.report(ok('textmate/'));
}

/** @returns {Promise<void>} */
async function verifyInternal() {
  const timer = new Timer('verifying internal');
  await run(['yarn', 'run', 'verify-internal'], addons);
  timer.report(ok('internal'));
}

/**
 * Verifies `isl/` and `isl-server/` and `vscode/` as the builds are interdependent.
 * @param {Args} args
 * @returns {Promise<void>}
 */
async function verifyIsl(args) {
  const timer = new Timer('verifying ISL');
  const isl = path.join(addons, 'isl');
  const islServer = path.join(addons, 'isl-server');
  const vscode = path.join(addons, 'vscode');

  await run(['yarn', 'codegen'], islServer);
  await Promise.all([run(['yarn', 'build'], islServer), run(['yarn', 'build'], isl)]);
  await Promise.all([
    run(['yarn', 'build-extension'], vscode),
    run(['yarn', 'build-webview'], vscode),
  ]);
  await Promise.all([lintAndTest(isl), lintAndTest(islServer), lintAndTest(vscode)]);
  if (!args.skipIntegrationTests) {
    timer.report('running isl integration tests');
    await runIslIntegrationTests();
  }
  timer.report(ok('ISL'));
}

/** @returns {Promise<void>} */
async function runIslIntegrationTests() {
  await run(['yarn', 'integration', '--watchAll=false'], path.join(addons, 'isl'));
}

/**
 * @param {string} cwd
 * @returns {Promise<void>}
 */
async function lintAndTest(cwd) {
  await Promise.all([
    run(['yarn', 'run', 'lint'], cwd),
    run(['yarn', 'run', 'tsc', '--noEmit'], cwd),
    run(['yarn', 'test', '--watchAll=false'], cwd),
  ]);
}

/**
 * @param {string[]} command
 * @param {string} cwd
 * @returns {Promise<void>}
 */
function run(command, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command[0], command.slice(1), {
      cwd,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    /** @type {Buffer[]} */
    const stdoutChunks = [];
    /** @type {Buffer[]} */
    const stderrChunks = [];

    child.stdout.on('data', chunk => {
      stdoutChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    });
    child.stderr.on('data', chunk => {
      stderrChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    });
    child.on('error', reject);
    child.on('close', code => {
      if (code === 0) {
        resolve();
        return;
      }

      const stdout = Buffer.concat(stdoutChunks).toString('utf8');
      const stderr = Buffer.concat(stderrChunks).toString('utf8');
      if (stdout !== '') {
        console.log(`[stdout]\n${stdout}`);
      }
      if (stderr !== '') {
        console.log(`[stderr]\n${stderr}`);
      }
      reject(new CommandError(command, code));
    });
  });
}

/**
 * @param {string} message
 * @returns {string}
 */
function ok(message) {
  return `\u001b[0;32mOK\u001b[00m ${message}`;
}

verify(parseArgs()).catch(error => {
  console.error(error);
  process.exit(1);
});
