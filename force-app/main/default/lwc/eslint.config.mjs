// SPDX-License-Identifier: BUSL-1.1
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
		// should enable them in their own eslint config.
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

		// KernDX Jest test-quality rules fire only on LWC test files.
		{
			plugins: {
				kerndx: kerndxPlugin
			}, files: ['**/*.test.js'], rules: {
				'kerndx/no-jest-theatre': 'error', 'kerndx/no-mutating-shared-fixture': 'error'
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