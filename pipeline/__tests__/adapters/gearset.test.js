// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const gearset = require('../../src/adapters/gearset.js');

const adapter = gearset.build({ name: 'gearset' }, { protected_branches: ['main', 'build', 's.i.t', 'uat'] });

test('back-promotion main_-_build', () => {
	assert.deepEqual(adapter.classifyHeadRef('gs-pipeline/main_-_build'),
		{ action: 'skip-scan', label: 'back-promotion' });
});

test('back-promotion s.i.t_-_uat (escaped dots in branch names)', () => {
	assert.deepEqual(adapter.classifyHeadRef('gs-pipeline/s.i.t_-_uat'),
		{ action: 'skip-scan', label: 'back-promotion' });
});

test('intercepted-feature gets full scan', () => {
	assert.deepEqual(adapter.classifyHeadRef('gs-pipeline/feature/DTCSF-1234_-_build'),
		{ action: 'full-scan', label: 'intercepted-feature' });
});

test('suspicious gs-pipeline prefix gets full scan + warning', () => {
	assert.deepEqual(adapter.classifyHeadRef('gs-pipeline/skip-tests'),
		{ action: 'full-scan', label: 'suspicious-prefix' });
});

test('normal feature branch unaffected', () => {
	assert.deepEqual(adapter.classifyHeadRef('feature/my-thing'),
		{ action: 'full-scan', label: 'normal' });
});
