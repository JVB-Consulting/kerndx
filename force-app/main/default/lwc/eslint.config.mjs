// SPDX-License-Identifier: Apache-2.0
// @ts-check

import globals from 'globals';
import path from 'node:path';
// noinspection JSUnresolvedReference
import {fileURLToPath} from 'node:url';
import js from '@eslint/js';
import eslint from '@eslint/js';
import {FlatCompat} from '@eslint/eslintrc';
import tseslint from 'typescript-eslint';
import importPlugin from 'eslint-plugin-import';
import {createRequire} from 'node:module';

const require = createRequire(import.meta.url);
const kerndxPlugin = require('../../../../scanner/eslint-plugin-kerndx');
// This allows us to use older rule sets
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
	baseDirectory: __dirname, recommendedConfig: js.configs.recommended, allConfig: js.configs.all
});

// noinspection JSCheckFunctionSignatures
export default tseslint.config(// Always use the recommended rule set
		eslint.configs.recommended,

		// LWC TypeScript non-test files,
		...compat.extends('@salesforce/eslint-config-lwc/recommended'),

		// KernDX "use the framework API" rules — subscriber-scoped.
		// The framework package itself necessarily extends LightningElement
		// in its base components and uses console.error in module-scoped
		// fallback functions. These rules are disabled here; subscribers
		// should enable them in their own eslint config. Because they are off
		// for the package's own components, those components carry no inline
		// eslint-disable comments for them. Release check 2.3e turns
		// use-component-builder on and allows only the components listed in
		// release-testing/runner/lightning-element-components.json.
		// {
		//     plugins: { kerndx: kerndxPlugin },
		//     files: ['**/*.js'], ignores: ['**/*.test.js'],
		//     rules: {
		//         'kerndx/use-component-builder': 'error',
		//         'kerndx/no-console-log': 'error',
		//         'kerndx/enforce-component-naming': 'error'
		//     }
		// },

		// KernDX coverage-exemption comment rule applies to every LWC JavaScript file
		// (production and test), since exempt comments may appear in either.
		{
			plugins: {
				kerndx: kerndxPlugin
			}, files: ['**/*.js'], rules: {
				'kerndx/no-coverage-exempt-without-reason': 'error'
			}
		},

		// KernDX i18n rule — surfaced here at `warn` for editor squiggles on
		// production LWC JavaScript. The authoritative gate (with per-area
		// warn->error staging) is `npm run lint:i18n`
		// (scanner/scan-hardcoded-user-text.js), which also covers .html and
		// .js-meta.xml. Test files are exempt (fixtures carry literal copy).
		{
			plugins: {
				kerndx: kerndxPlugin
			}, files: ['**/*.js'], ignores: ['**/*.test.js'], rules: {
				'kerndx/no-hardcoded-user-text': 'warn'
			}
		},

		// Two components fetch one object at a time on purpose: a small pool of workers each
		// awaits its next object inside a loop, so the work stays cancellable, shows progress
		// for each object and never floods the server with calls. The await inside the loop
		// is the design (startScan in dataMaskingAdvisor, startFetch in maskingInventoryExportDialog),
		// so no-await-in-loop is off for these two files only. Any other await in a loop there needs its own reason.
		{
			files: [
				'**/dataMaskingAdvisor/dataMaskingAdvisor.js',
				'**/maskingInventoryExportDialog/maskingInventoryExportDialog.js'
			], rules: {
				'no-await-in-loop': 'off'
			}
		},

		// KernDX Jest test-quality rules fire only on LWC test files.
		{
			plugins: {
				kerndx: kerndxPlugin
			}, files: ['**/*.test.js'], rules: {
				'kerndx/no-jest-theatre': 'error', 'kerndx/no-mutating-shared-fixture': 'error', 'kerndx/no-jest-mock-component-module': 'error'
			}
		},

		// Jest specs assert on rendered DOM: READING innerHTML in an expectation is not the
		// XSS-sink write @lwc/lwc/no-inner-html guards against, so the rule is off for specs
		// only. Production components keep it at full strength.
		{
			files: ['**/*.test.js'], rules: {
				'@lwc/lwc/no-inner-html': 'off'
			}
		},

		{
			extends: [...tseslint.configs.recommended], plugins: {
				import: importPlugin
			}, files: ['**/*.ts'], languageOptions: {
				globals: {
					...globals.node
				}
			}, rules: {
				'@typescript-eslint/no-explicit-any': 'off'
			}, settings: {
				'import/resolver': {
					typescript: true
				}
			}
		},

		// LWC TypeScript Jest tests
		{
			extends: [...tseslint.configs.recommended], plugins: {
				import: importPlugin
			}, files: ['**/*.test.ts'], languageOptions: {
				globals: {
					...globals.node
				}
			}, rules: {
				'@lwc/lwc/no-unexpected-wire-adapter-usages': 'off',
				'@lwc/lwc/no-async-operation': 'off',
				'jest/no-conditional-expect': 'off',
				'@typescript-eslint/no-explicit-any': 'off'
			}, settings: {
				'import/resolver': {
					typescript: true
				}
			}
		},

		// LWC JavaScript Jest tests
		{
			files: ['**/*.test.js'], languageOptions: {
				globals: {
					...globals.node
				}
			}, rules: {
				'@lwc/lwc/no-unexpected-wire-adapter-usages': 'off', '@lwc/lwc/no-async-operation': 'off', 'jest/no-conditional-expect': 'off'
			}
		});