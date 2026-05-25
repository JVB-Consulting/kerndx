// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const none = require('../../src/adapters/none.js');

test('none adapter classifies every ref as full-scan/normal', () => {
	const a = none.build({ name: 'none' }, { protected_branches: ['main'] });
	assert.deepEqual(a.classifyHeadRef('main'), { action: 'full-scan', label: 'normal' });
	assert.deepEqual(a.classifyHeadRef('feature/anything'), { action: 'full-scan', label: 'normal' });
	assert.deepEqual(a.classifyHeadRef('gs-pipeline/whatever'), { action: 'full-scan', label: 'normal' });
});
