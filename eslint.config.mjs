// SPDX-License-Identifier: BUSL-1.1
// ESLint 8.57 selects its flat configuration when this file exists at the project root, so the LWC lint runs from
// every terminal without an environment variable. The LWC configuration lives beside the components; the block
// below adds the Node tooling overrides for the release-testing harness.
import globals from 'globals';
import lwcConfiguration from './force-app/main/default/lwc/eslint.config.mjs';

export default [
	// What the old .eslintignore kept out: ESLint 10 no longer reads that file. A workflow script runs inside the
	// Workflow tool, where `agent`, `phase`, `pipeline`, `args` and `log` are given, so it cannot be linted as a module.
	{
		ignores: [
			'**/*.workflow.mjs',
			'evidence/**',
			'_repos/**',
			'.sfdx/**'
		]
	},

	...lwcConfiguration,

	// The release-testing harness is Node tooling and Playwright specs, not Lightning components. It needs Node
	// globals, and its Playwright steps wait one after another on purpose, so no-await-in-loop is off. The LWC-only
	// rules do not describe this code.
	{
		files: ['release-testing/**/*.js', 'release-testing/**/*.mjs'], languageOptions: {
			globals: {
				...globals.es2021, ...globals.node
			}
		}, rules: {
			'no-await-in-loop': 'off',
			'@lwc/lwc/no-async-operation': 'off',
			'@lwc/lwc/no-document-query': 'off',
			'kerndx/no-hardcoded-user-text': 'off'
		}
	},

	// The maintainer scripts and the pipeline package are Node tooling too: CommonJS modules that read `module`,
	// `process` and `__dirname`, run commands one after another on purpose, and print to a terminal rather than to a
	// subscriber's page. Without this block every one of those globals was an error nobody could clear, so the real
	// findings in these folders were read past. The rules written for Lightning components and their Jest suites
	// (DOM queries, timers, user-facing text, the Jest theatre check, which also fires on node:test files) are off.
	{
		files: ['scripts/**/*.js', 'scripts/**/*.mjs', 'pipeline/**/*.js', 'pipeline/**/*.mjs'], languageOptions: {
			globals: {
				...globals.es2021, ...globals.node
			}
		}, rules: {
			'no-await-in-loop': 'off',
			'@lwc/lwc/no-async-operation': 'off',
			'@lwc/lwc/no-document-query': 'off',
			'@lwc/lwc/no-inner-html': 'off',
			'kerndx/no-hardcoded-user-text': 'off',
			'kerndx/no-jest-theatre': 'off',
			'kerndx/no-mutating-shared-fixture': 'off',
			// Script suites that need a live file or an opted-in environment alias `it` to `it` or `it.skip` under
			// these names; the rule cannot see through a plain alias on its own.
			'jest/no-standalone-expect': [
				'error', {
					additionalTestBlockFunctions: [
						'itIfFileModesApply',
						'itIfManifest',
						'itOnWindows',
						'maybeIt'
					]
				}
			]
		}
	}
];
