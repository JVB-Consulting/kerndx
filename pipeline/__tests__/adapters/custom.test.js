// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const custom = require('../../src/adapters/custom.js');

const config = {
	name: 'custom', patterns: [
		{match: '^my-tool/sync-.*$', action: 'skip-scan', label: 'back-promotion'},
		{match: '^my-tool/feature/.+$', action: 'full-scan', label: 'intercepted-feature'}
	]
};

test('custom adapter applies first matching pattern', () =>
{
	const a = custom.build(config, {protected_branches: ['main']});
	assert.deepEqual(a.classifyHeadRef('my-tool/sync-prod'), {action: 'skip-scan', label: 'back-promotion'});
	assert.deepEqual(a.classifyHeadRef('my-tool/feature/x'), {action: 'full-scan', label: 'intercepted-feature'});
	assert.deepEqual(a.classifyHeadRef('feature/normal'), {action: 'full-scan', label: 'normal'});
});
