/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {PluginOption} from 'vite';

// import babel from '@rolldown/plugin-babel';
import react from '@vitejs/plugin-react';
import {existsSync} from 'node:fs';
import path from 'node:path';
import {defineConfig} from 'vite';

// Normalize `c:\foo\index.html` to `c:/foo/index.html`.
// This affects Rolldown's `facadeModuleId` (which expects the `c:/foo/bar` format),
// and is important for Vite to replace the script tags in HTML files.
// See https://github.com/vitejs/vite/blob/7440191715b07a50992fcf8c90d07600dffc375e/packages/vite/src/node/plugins/html.ts#L804
// Without this, building on Windows might produce HTML entry points with
// missing `<script>` tags, resulting in a blank page.
function normalizeInputPath(inputPath: string) {
  return process.platform === 'win32' ? path.resolve(inputPath).replace(/\\/g, '/') : inputPath;
}

const isInternal = existsSync(path.resolve(__dirname, 'facebook/README.facebook.md'));

const input = [normalizeInputPath('webview.html')];
if (isInternal) {
  // Currently, the inline comment webview is not used in OSS
  input.push(normalizeInputPath('inlineCommentWebview.html'));
  input.push(normalizeInputPath('DiffCommentPanelWebview.html'));
  input.push(normalizeInputPath('InlineCommentPanelWebview.html'));
  input.push(normalizeInputPath('diffSignalWebview.html'));
}

console.log(isInternal ? 'Building internal version' : 'Building OSS version');

const replaceFiles = (
  replacements?: Array<{
    file: string;
    replacement: string;
  }>,
): PluginOption => {
  const projectRoot = process.cwd();
  replacements = replacements?.map(x => ({
    file: path.join(projectRoot, x.file).replace(/\\/g, '/'),
    replacement: path.join(projectRoot, x.replacement).replace(/\\/g, '/'),
  }));

  return {
    name: 'vite-plugin-replace-files',
    enforce: 'pre',
    async resolveId(source: string, importer: string | undefined, options: any) {
      const resolvedFile = await this.resolve(source, importer, {
        ...options,
        ...{skipSelf: true},
      });

      const foundReplacementFile = replacements?.find(
        replacement => replacement.file == resolvedFile?.id,
      );

      if (foundReplacementFile) {
        return {
          id: foundReplacementFile.replacement,
        };
      }
      return null;
    },
  };
};

export default defineConfig(({mode}) => ({
  base: '',
  resolve: {
    tsconfigPaths: true,
  },
  plugins: [
    replaceFiles([
      {
        file: '../isl/src/platform.ts',
        replacement: './webview/vscodeWebviewPlatform.tsx',
      },
    ]),

    react(),
    // babel({
    //   plugins: [
    //     [
    //       'jotai/babel/plugin-debug-label',
    //       {
    //         customAtomNames: [
    //           'atomFamilyWeak',
    //           'atomLoadableWithRefresh',
    //           'atomWithOnChange',
    //           'atomWithRefresh',
    //           'configBackedAtom',
    //           'jotaiAtom',
    //           'lazyAtom',
    //           'localStorageBackedAtom',
    //         ],
    //       },
    //     ],
    //   ],
    // }),
  ],
  build: {
    outDir: 'dist/webview',
    manifest: true,
    // FIXME: This means that all webviews will use the same css file.
    // This is too bloated for the inline comment webview and marginally slows down startup time.
    // Ideally, we'd load all the relevant css files in the webview, but our current approach
    // with our own manual copy of html in htmlForWebview does not support this.
    cssCodeSplit: false,
    rolldownOptions: {
      input,
      output: {
        // Don't use hashed names, so ISL webview panel can pre-define what filename to load
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: 'res/[name].[ext]',
      },
    },
    copyPublicDir: true,
    // No need for source maps in production. We can always build them locally to understand a wild stack trace.
    sourcemap: mode === 'development',
  },
  worker: {
    rolldownOptions: {
      output: {
        // Don't use hashed names, so ISL webview panel can pre-define what filename to load
        entryFileNames: 'worker/[name].js',
        chunkFileNames: 'worker/[name].js',
        assetFileNames: 'worker/[name].[ext]',
      },
    },
  },
  publicDir: '../isl/public',
  server: {
    // No need to open the browser, we run inside vscode and don't really connect to the server.
    open: false,
    port: 3015,
    cors: {
      origin: /^vscode-webview:\/\/.*/,
    },
  },
}));
