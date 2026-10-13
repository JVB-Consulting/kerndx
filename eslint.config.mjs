// SPDX-License-Identifier: BUSL-1.1
// ESLint 8.57 selects its flat configuration when this file exists at the project root, so the LWC lint runs from
// every terminal without an environment variable. The LWC configuration lives beside the components; the block
// below adds the Node tooling overrides for the release-testing harness.
import globals from 'globals';
import lwcConfiguration from './force-app/main/default/lwc/eslint.config.mjs';

export default [
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
	}
];
