// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSfcaArgs } = require('../../src/lib/sfca-runner.js');

test('buildSfcaArgs assembles --target flags per file', () => {
	const args = buildSfcaArgs({
		workspace: 'force-app',
		configFile: 'code-analyzer.yml',
		ruleSelector: 'pmd,flow,eslint',
		files: ['a.cls', 'b.cls'],
		severityThreshold: 1,
	});
	assert.deepEqual(args, [
		'code-analyzer', 'run',
		'--workspace', 'force-app',
		'--config-file', 'code-analyzer.yml',
		'--rule-selector', 'pmd,flow,eslint',
		'--severity-threshold', '1',
		'--target', 'a.cls',
		'--target', 'b.cls',
	]);
});

test('buildSfcaArgs omits --severity-threshold when null (CI mode handles it via output check)', () => {
	const args = buildSfcaArgs({
		workspace: 'force-app',
		configFile: 'code-analyzer.yml',
		ruleSelector: 'pmd',
		files: ['x.cls'],
		severityThreshold: null,
	});
	assert.ok(!args.includes('--severity-threshold'));
});
