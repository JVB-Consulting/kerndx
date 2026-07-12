// SPDX-License-Identifier: BUSL-1.1
// Isolated flat config for the i18n gate (`npm run lint:i18n`).
//
// It enables ONLY `kerndx/no-hardcoded-user-text` so the gate's green/red signal
// depends purely on hardcoded user text — it is deliberately NOT affected by the
// repo's broader eslint ruleset or its pre-existing non-i18n backlog. The rule is
// also registered in force-app/main/default/lwc/eslint.config.mjs for editor
// squiggles; this config is the JS leg of `scanner/scan-hardcoded-user-text.js`.
//
// It reports every violation at `warn` (uniform). Severity STAGING — which bundles
// are ERROR (fail the gate) vs WARN — is applied by the runner from
// scanner/i18n-swept-areas.json, so it is expressed in one place for `.js`,
// `.html`, and `.js-meta.xml` alike.

import babelParser from '@babel/eslint-parser';
import kerndxPlugin from './eslint-plugin-kerndx/index.js';

// The LWC decorator-aware parser setup (mirrors @salesforce/eslint-config-lwc
// lib/defaults.js) — needed so espree does not choke on `@api`/`@track`/`@wire`.
const languageOptions = {
	ecmaVersion: 'latest', sourceType: 'module', parser: babelParser, parserOptions: {
		requireConfigFile: false, babelOptions: {
			babelrc: false,
			configFile: false,
			parserOpts: {
				plugins: [
					[
						'decorators',
						{decoratorsBeforeExport: false}
					]
				]
			}
		}
	}
};

export default [
	{
		ignores: [
			'**/node_modules/**',
			'evidence/**',
			'**/*.test.js',
			'**/__tests__/**',
			'scanner/**'
		]
	},
	{
		// Only this rule is enabled, so the `@lwc/*`/`@salesforce/*` disable comments
		// scattered through the tree are "unused"/"undefined" from this config's view —
		// do not report those, or they would pollute the i18n signal.
		linterOptions: {reportUnusedDisableDirectives: 'off'}
	},
	{
		files: ['force-app/**/lwc/**/*.js'], plugins: {kerndx: kerndxPlugin}, languageOptions, rules: {'kerndx/no-hardcoded-user-text': 'warn'}
	}
];
